# frozen_string_literal: true

module Communitarian
  class Resolution
    REOPENED_RESOLUTION_ATTRIBUTES = %w[
      topic_id post_type
    ].freeze

    attr_reader :resolution_schedule

    def initialize(resolution_schedule)
      @resolution_schedule = resolution_schedule
    end

    def reopen_weekly_resolution!(resolution)
      return if to_be_closed?(resolution)

      generate_weekly_report(resolution)
      poll = resolution.polls.first
      next_close_time = resolution_schedule.next_close_time(poll.close_at)

      poll.update!(close_at: next_close_time, status: "open")

      self.schedule_jobs(resolution)
    end

    def schedule_jobs(post)
      ::DiscoursePoll::Poll.schedule_jobs(post)
      return if to_be_closed?(post)

      job_args = { post_id: post.id }
      poll = post.polls.first

      next_reopen_time = if poll.created_at.today?
        poll.close_at + Communitarian::ResolutionSchedule.reopen_delay
      else
        resolution_schedule.next_reopen_time
      end

      Jobs.cancel_scheduled_job(:reopen_resolution, job_args)
      Jobs.enqueue_at(next_reopen_time, :reopen_resolution, job_args)
    end

    private

    def to_be_closed?(post)
      post.user_deleted || post.topic.blank? || !resolution?(post) || close_by_vote?(post) || closed_by_system?(post)
    end

    def generate_weekly_report(resolution)
      report_attributes = resolution.attributes.slice(*self.class::REOPENED_RESOLUTION_ATTRIBUTES)
      report = Post.create!(report_attributes.merge(user_id: -1, raw: report_raw(resolution)))
      report.custom_fields["is_weekly_report"] = true
      report.save_custom_fields(true)
      report.reload
    end

    def report_raw(resolution)
      poll_options = resolution.polls.includes(poll_options: :poll_votes).first.poll_options
      week_number = PostCustomField.where(name: :is_weekly_report, post_id: resolution.topic.post_ids).count + 1
      raw = "Week #{week_number} result:"
      poll_options.each do |poll_option|
        raw += "\n* #{poll_option.html}: #{I18n.t(:voted_people, count: poll_option.poll_votes.size)}"
      end
      raw
    end

    def close_by_vote?(post)
      return false unless post.polls.exists?

      resolution_stats = Communitarian::ResolutionStats.new(post.polls.first)

      resolution_stats.to_close?
    end

    # this check needs to ignore Jobs::ClosePoll job that closing resolution
    # on the same time when we trying to renew it
    def closed_by_system?(post)
      post.polls.first.close_at < Date.today
    end

    def resolution?(post)
      post.is_resolution? && post.polls.exists?
    end
  end
end

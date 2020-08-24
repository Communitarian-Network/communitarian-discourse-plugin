# frozen_string_literal: true

module Communitarian
  class Resolution
    REOPENED_RESOLUTION_ATTRIBUTES = %w[
      user_id topic_id raw post_type last_editor_id last_version_at user_deleted public_version
    ].freeze

    attr_reader :resolution_schedule

    def initialize(resolution_schedule)
      @resolution_schedule = resolution_schedule
    end

    def reopen_weekly_resolution!(original_post)
      return if to_be_closed?(original_post) || !reopen(original_post)

      post_attributes = original_post.attributes.slice(*self.class::REOPENED_RESOLUTION_ATTRIBUTES)
      post = Post.create!(post_attributes)
      poll = post.reload.polls.first
      poll.update!(close_at: resolution_schedule.next_close_time(poll.close_at))
      self.schedule_jobs(post)
    end

    def schedule_jobs(post)
      ::DiscoursePoll::Poll.schedule_jobs(post)
      return if to_be_closed?(post)

      job_args = { post_id: post.id }
      Jobs.cancel_scheduled_job(:reopen_resolution, job_args)

      if reopen?(post)
        Jobs.enqueue_at(resolution_schedule.next_reopen_time(post.created_at), :reopen_resolution, job_args)
      end
    end

    private

    def to_be_closed?(post)
      post.user_deleted || !resolution?(post) || close_by_vote?(post)
    end

    def close_by_vote?(post)
      @resolution_stats ||= Communitarian::ResolutionStats.new(post.polls.first)

      @resolution_stats.to_close?
    end

    def resolution?(post)
      post.topic.custom_fields["is_resolution"] && post.polls.exists?
    end

    def reopen?(post)
      resolution_polls = Poll.includes(:post).where("post.topic_id = ?", post.topic_id).order(:created_at)
      !to_be_closed?(post) && resolution_polls.last.created_at < 5.days.ago
    end
  end
end

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
      return if to_be_closed?(original_post)

      post_attributes = original_post.attributes.slice(*self.class::REOPENED_RESOLUTION_ATTRIBUTES)
      post = Post.create!(post_attributes)
      post.custom_fields["is_resolution"] = true
      post.save_custom_fields(true)
      poll = post.reload.polls.first
      poll.update!(close_at: resolution_schedule.next_close_time)
      self.reorder_resolutions!(original_post.topic)
      self.schedule_jobs(post)
    end

    def reorder_resolutions!(topic)
      resolutions = topic.posts.select { |p| p.custom_fields["is_resolution"] }

      sort_orders = resolutions.pluck(:sort_order).sort
      resolutions.sort! { |r1, r2| r2.created_at <=> r1.created_at }

      Post.transaction do
        resolutions.zip(sort_orders) do |resolution, order|
          resolution.update(sort_order: order)
        end
      end
    end

    def schedule_jobs(post)
      ::DiscoursePoll::Poll.schedule_jobs(post)
      return if to_be_closed?(post)

      job_args = { post_id: post.id }
      Jobs.cancel_scheduled_job(:reopen_resolution, job_args)
      Jobs.enqueue_at(resolution_schedule.next_reopen_time, :reopen_resolution, job_args)
    end

    private

    def to_be_closed?(post)
      post.user_deleted || !resolution?(post) || close_by_vote?(post)
    end

    def close_by_vote?(post)
      resolution_stats = Communitarian::ResolutionStats.new(post.polls.first)

      resolution_stats.to_close?
    end

    def resolution?(post)
      post.custom_fields["is_resolution"] && post.polls.exists?
    end
  end
end

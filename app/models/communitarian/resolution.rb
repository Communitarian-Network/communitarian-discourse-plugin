# frozen_string_literal: true

require_relative "../../jobs/regular/reopen_resolution"
require_relative "../post"

module Communitarian
  class Resolution
    using Communitarian

    REOPENED_RESOLUTION_ATTRIBUTES = %w[
      user_id topic_id raw post_type last_editor_id last_version_at user_deleted public_version
    ].freeze

    def self.reopen_weekly_resolution!(original_post)
      return if original_post.user_deleted || !original_post.resolution?

      post_attributes = original_post.attributes.slice(*self.REOPENED_RESOLUTION_ATTRIBUTES)
      post = Post.create!(post_attributes)
      poll = post.reload.polls.first
      poll.update!(close_at: self.next_close_time)
      self.schedule_jobs(post)
    end

    def self.schedule_jobs(post)
      return unless post.resolution?

      ::DiscoursePoll::Poll.schedule_jobs(post)
      job_args = { post_id: post.id }
      Jobs.cancel_scheduled_job(:reopen_resolution, job_args)
      Jobs.enqueue_at(self.next_reopen_time(post.polls.first.close_at), :reopen_resolution, job_args)
    end
  end
end

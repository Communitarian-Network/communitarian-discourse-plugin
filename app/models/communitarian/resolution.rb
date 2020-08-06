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
      poll.update!(close_at: self.next_close_time, is_weekly: true)
      self.schedule_jobs(post)
    end

    def self.schedule_jobs(post)
      return unless post.resolution?

      ::DiscoursePoll::Poll.schedule_jobs(post)
      job_args = { post_id: post.id }
      Jobs.cancel_scheduled_job(:reopen_resolution, job_args)
      Jobs.enqueue_at(self.next_reopen_time(post.polls.first.close_at), :reopen_resolution, job_args)
    end

    def self.next_close_time(today = self.current_time)
      next_close_day = if (self.close_week_day - today.wday) % 7 < 2
        (today + 1.week).end_of_week
      else
        today.end_of_week
      end
      next_close_day.change(hour: self.close_hour)
    end

    def self.next_reopen_time(today = self.current_time)
      self.next_close_time(today) + self.reopen_delay
    end

    def self.current_time
      ActiveSupport::TimeZone["America/New_York"].now
    end

    def self.close_week_day
      # TODO: replace 0 with reading the setting
      0
    end

    def self.close_hour
      # TODO: replace 20 with reading the setting
      20
    end

    def self.reopen_delay
      # TODO: read this value from the settings
      12.hours
    end
  end
end

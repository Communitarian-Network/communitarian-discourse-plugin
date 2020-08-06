# frozen_string_literal: true

require_relative "../user"

module Communitarian
  class PostDelay
    using Communitarian

    attr_reader :delay

    def initialize(delay = self.class.delay_setting)
      @delay = delay
    end

    def call(manager)
      if manager.user.posted_after?(delay.ago, manager.args[:topic_id])
        result = NewPostResult.new(:post, false)
        result.errors[:base] << I18n.t("model.post.delay.error", period: delay.inspect)
        result
      end
    end

    def self.delay_setting
      SiteSetting.post_delay.seconds
    end
  end
end

require_relative "user"

module Communitarian
  class PostDelay
    using Communitarian

    def self.call(manager)
      if manager.user.posted_recently?(manager.args[:topic_id])
        result = NewPostResult.new(:post, false)
        result.errors[:base] << I18n.t("model.post.delay.error", period: 5.minutes.inspect)
        result
      end
    end
  end
end

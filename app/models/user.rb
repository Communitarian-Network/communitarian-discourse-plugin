# frozen_string_literal: true

module Communitarian
  refine User do
    def posted_recently?(topic_id)
      self.posts.where(topic_id: topic_id).where("created_at > ?", 5.minutes.ago).exists?
    end
  end
end

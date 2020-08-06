# frozen_string_literal: true

module Communitarian
  refine User do
    def posted_after?(timestamp, topic_id)
      self.posts.where(topic_id: topic_id).where("created_at > ?", timestamp).exists?
    end
  end
end

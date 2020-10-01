# frozen_string_literal: true

module Communitarian
  class ResolutionTitle
    def self.create_suffix_for!(topic)
      new_title = new(topic).to_s
      topic.update!(title: new_title)
    end

    def initialize(topic)
      @topic = topic
    end

    def to_s
      "#{topic.title} - #{category_abbreviation} #{topic.id}"
    end

    private

    attr_reader :topic

    def category_abbreviation
      topic.category.custom_fields["community_code"]
    end
  end
end
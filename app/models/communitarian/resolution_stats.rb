# frozen_string_literal: true

module Communitarian
  class ResolutionStats
    attr_reader :poll

    def initialize(poll)
      @poll = poll
    end

    def votes
      @votes ||= poll.poll_options.map do |option|
        [option.html, option.poll_votes.size + option.anonymous_votes.to_i]
      end.to_h
    end

    def to_close?
      decision, votes_count = votes.max_by { |_, v| v }

      votes_count > 0 &&
        decision == I18n.t("js.communitarian.resolution.ui_builder.poll_options.close_option")
    end
  end
end

# frozen_string_literal: true

require_relative "../../jobs/regular/reopen_resolution"

module Communitarian
  class ResolutionStats
    attr_reader :poll

    def initialize(poll)
      @poll = poll
    end

    def votes
      @votes ||= poll.poll_options.map do |option|
        [option.html, option.poll_votes.size + object.anonymous_votes.to_i]
      end.to_h
    end

    def to_close?
      votes.max_by { |_, v| v }[0] == "Close the poll"
    end
  end
end

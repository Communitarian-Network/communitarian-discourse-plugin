# frozen_string_literal: true

module Communitarian
  class ResolutionSchedule
    WEEKDAYS = Date::DAYS_INTO_WEEK.keys.freeze

    attr_reader :close_hour, :reopen_delay

    def initialize(close_weekday: self.class.close_weekday,
                   close_hour:    self.class.close_hour,
                   reopen_delay:  self.class.reopen_delay)
      @close_weekday = close_weekday
      @close_hour = close_hour
      @reopen_delay = reopen_delay
    end

    def next_close_time(today = self.class.current_time)
      next_close_day = today.next_occurring(self.close_weekday)
      next_close_day.change(hour: self.close_hour)
    end

    def next_reopen_time(today = self.class.current_time)
      self.next_close_time(today) + self.reopen_delay
    end

    def close_weekday
      self.class::WEEKDAYS[@close_weekday]
    end

    def self.current_time
      ActiveSupport::TimeZone["America/New_York"].now
    end

    def self.close_weekday
      Date::DAYS_INTO_WEEK[SiteSetting.communitarian_resolutions_close_week_day.downcase.to_sym] || 0
    end

    def self.close_hour
      SiteSetting.communitarian_resolutions_close_hour % 24
    end

    def self.reopen_delay
      SiteSetting.communitarian_resolutions_reopen_delay.hours
    end
  end
end

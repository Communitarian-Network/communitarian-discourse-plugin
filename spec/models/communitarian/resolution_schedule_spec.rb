# frozen_string_literal: true

require "rails_helper"

RSpec.describe Communitarian::ResolutionSchedule, type: :model do
  before { Communitarian::ResolutionSchedule.stubs(:current_time).returns(current_time) }

  # Closes on Sunday
  subject(:schedule) { described_class.new(close_weekday: 0, close_hour: 20, reopen_delay: 4.hours) }

  context "when today is the resolution close day" do
    # Sunday
    let(:current_time) { Time.zone.parse("2020-08-09 12:00:00 UTC") }

    describe ".next_close_time" do
      it "returns a day on the next week" do
        expect(schedule.next_close_time).to eq(Time.zone.parse("2020-08-16 20:00:00 UTC"))
      end
    end

    describe ".next_reopen_time" do
      it "returns next_close_time with delay" do
        expect(schedule.next_reopen_time).to eq(Time.zone.parse("2020-08-17 00:00:00 UTC"))
      end
    end
  end

  context "when today is not the resolution close day" do
    # Friday
    let(:current_time) { Time.zone.parse("2020-08-07 15:00:00 UTC") }

    describe ".next_close_time" do
      it "returns a day on the next week" do
        expect(schedule.next_close_time).to eq(Time.zone.parse("2020-08-09 20:00:00 UTC"))
      end
    end

    describe ".next_reopen_time" do
      it "returns next_close_time with delay" do
        expect(schedule.next_reopen_time).to eq(Time.zone.parse("2020-08-10 00:00:00 UTC"))
      end
    end
  end
end

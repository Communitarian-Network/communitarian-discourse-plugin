# frozen_string_literal: true

require "rails_helper"

RSpec.describe Communitarian::ResolutionStats, type: :model do
  subject(:resolution_stats) { described_class.new(poll) }

  let(:poll) { stub(poll_options: poll_options) }
  let(:poll_options) do
    ["Good", "Bad", I18n.t("js.communitarian.resolution.ui_builder.poll_options.close_option")]
      .map { |option_label| stub(html: option_label, anonymous_votes: 0, poll_votes: []) }
  end

  describe ".to_close?" do
    subject(:to_close?) { resolution_stats.to_close? }

    let(:good_choice) { poll.poll_options.first }
    let(:bad_choice) { poll.poll_options.second }
    let(:close_choice) { poll.poll_options.last }

    context "when most of users chose to close poll" do
      before do
        good_choice.stubs(:poll_votes).returns(Array.new(2) { mock("poll_vote") })
        bad_choice.stubs(:poll_votes).returns(Array.new(1) { mock("poll_vote") })
        close_choice.stubs(:poll_votes).returns(Array.new(3) { mock("poll_vote") })
      end

      it { is_expected.to eq true }
    end

    context "when users chose some other option" do
      before { good_choice.stubs(:poll_votes).returns([mock("poll_vote")]) }

      it { is_expected.to eq false }
    end

    context "when no voters at all" do
      it { is_expected.to eq false }
    end
  end
end

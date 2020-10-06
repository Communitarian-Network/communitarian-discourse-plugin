# frozen_string_literal: true

require "rails_helper"

require "user"

RSpec.describe User, type: :model do
  using Communitarian

  let(:user) { Fabricate(:user) }

  describe ".posted_after?" do
    subject { user.posted_after?(5.minutes.ago, post.topic_id) }

    context "when there is a fresh post in the topic by the user" do
      let(:post) { Fabricate(:post, user: user, created_at: 3.minutes.ago) }

      it { is_expected.to eq true }
    end

    context "when there is an old post in the topic by the user" do
      let(:post) { Fabricate(:post, user: user, created_at: 7.minutes.ago) }

      it { is_expected.to eq false }
    end
  end
end

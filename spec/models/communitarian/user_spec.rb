require "rails_helper"

RSpec.describe User, type: :model do
  using Communitarian

  let(:user) { Fabricate(:user) }

  describe ".posted_recently?" do
    subject { user.posted_recently?(post.topic_id) }

    context "when there is a fresh post in the topic by the user" do
      let(:post) { Fabricate(:post, user: user, created_at: 3.minutes.ago) }

      it { is_expected.to eq true }
    end

    context "when there is an old post in the topic by the user" do
      let(:post) { Fabricate(:post, user: user, created_at: 1.day.ago) }

      it { is_expected.to eq false }
    end
  end
end

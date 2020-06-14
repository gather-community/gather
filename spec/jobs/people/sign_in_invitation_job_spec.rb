# frozen_string_literal: true

require "rails_helper"

describe People::SignInInvitationJob do
  include_context "jobs"

  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:user3) { create(:user, community: create(:community)) }
  let!(:decoy) { create(:user) }
  let(:user_ids) { [user1, user2, user3].map(&:id) }
  subject(:job) { described_class.new(user1.community_id, user_ids) }

  it "should send correct number of invites" do
    expect(AuthMailer).to receive(:sign_in_invitation).exactly(2).times.and_return(mlrdbl)
    perform_job
  end

  it "should send invites to selected users in own community only" do
    # The UI won't let anyone pick users in other communities but just in case, we ensure they aren't sent.
    expect(AuthMailer).to receive(:sign_in_invitation).with(user1, any_args).and_return(mlrdbl)
    expect(AuthMailer).to receive(:sign_in_invitation).with(user2, any_args).and_return(mlrdbl)
    perform_job
  end
end

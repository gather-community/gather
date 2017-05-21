require 'rails_helper'

describe People::InviteJob do
  include_context "jobs"

  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:decoy) { create(:user) }
  let(:user_ids) { [user1, user2].map(&:id) }
  let(:args) { [user1.community_id, user_ids] }

  it "should send correct number of invites" do
    expect(DeviseMailer).to receive(:reset_password_instructions).exactly(2).times.and_return(mlrdbl)
    perform_job(*args)
  end

  it "should send invites to selected users" do
    expect(DeviseMailer).to receive(:reset_password_instructions).with(user1, any_args).and_return(mlrdbl)
    expect(DeviseMailer).to receive(:reset_password_instructions).with(user2, any_args).and_return(mlrdbl)
    perform_job(*args)
  end
end

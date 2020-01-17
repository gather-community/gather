# frozen_string_literal: true

require "rails_helper"

describe Groups::MembershipMaintainer do
  context "on user deactivate" do
    let(:user) { create(:user) }

    context "with group membership" do
      let!(:membership) { create(:group_membership, user: user) }

      it "destroys memberships" do
        user.deactivate
        expect { membership.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with no group membership" do
      it "runs cleanly" do
        user.deactivate
        user.activate
      end
    end
  end

  context "on affiliation destroy" do
    let!(:community1) { Defaults.community }
    let!(:community2) { create(:community) }
    let!(:user1) { create(:user, community: community1) }
    let!(:user2) { create(:user, community: community2) }
    let!(:group) { create(:group, communities: [community1, community2], joiners: [user1, user2]) }

    it "destroys appropriate memberships" do
      group.affiliations.detect { |a| a.community == community2 }.destroy
      expect(group.reload.memberships.map(&:user)).to eq([user1])
    end
  end
end

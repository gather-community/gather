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

    context "when no affiliations left" do
      it "destroys group" do
        group.affiliations.each(&:destroy)
        expect { group.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  context "on household community change" do
    let!(:community1) { Defaults.community }
    let!(:community2) { create(:community) }
    let!(:household) { create(:household, member_count: 2, community: community1) }
    let!(:user) { create(:user) }
    let!(:group) do
      create(:group, communities: [community1, community2], joiners: household.users + [user])
    end

    context "when changing to other community within in group" do
      it "preserves memberships" do
        household.update!(community: community2)
        expect(group.reload.memberships.map(&:user)).to match_array(household.users + [user])
      end
    end

    context "when changing to community not in group" do
      let!(:community3) { create(:community) }

      it "destroys appropriate memberships" do
        household.update!(community: community3)
        expect(group.reload.memberships.map(&:user)).to eq([user])
      end
    end
  end
end

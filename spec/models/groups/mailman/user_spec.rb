# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::User do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_user)
    end
  end

  describe "#syncable?" do
    let(:fake) { false }
    let(:user) { create(:user, fake: fake) }
    let!(:mm_user) { create(:group_mailman_user, user: user) }
    subject(:syncable) { mm_user.syncable? }

    context "with non-fake user" do
      it { is_expected.to be(true) }
    end

    context "when user is fake" do
      let(:fake) { true }
      it { is_expected.to be(false) }
    end
  end

  describe "#list_memberships" do
    let!(:mm_user) { create(:group_mailman_user) }
    let!(:user) { mm_user.user }

    # Not included b/c opt out
    let!(:group1) { create(:group, availability: "everybody") }
    let!(:membership1) { create(:group_membership, group: group1, user: user, kind: "opt_out") }

    # Included as member
    let!(:group2) { create(:group, availability: "open") }
    let!(:list1) { create(:group_mailman_list, group: group2) }
    let!(:membership2) { create(:group_membership, group: group2, user: user, kind: "joiner") }

    # Included as owner
    let!(:group3) { create(:group, availability: "open") }
    let!(:list2) { create(:group_mailman_list, group: group3) }
    let!(:membership3) { create(:group_membership, group: group3, user: user, kind: "manager") }

    # Not included b/c no list
    let!(:group4) { create(:group, availability: "open") }
    let!(:membership4) { create(:group_membership, group: group4, user: user) }

    # Not included b/c different user
    let!(:decoy) { create(:group_membership, group: group3) }

    let!(:list_memberships) { mm_user.list_memberships }
    let!(:list_memberships_by_list_id) { list_memberships.index_by(&:list_id) }

    it "returns correct results" do
      expect(list_memberships.size).to eq(2)
      expect(list_memberships_by_list_id[list1.remote_id].mailman_user).to eq(mm_user)
      expect(list_memberships_by_list_id[list1.remote_id].role).to eq("member")
      expect(list_memberships_by_list_id[list2.remote_id].mailman_user).to eq(mm_user)
      expect(list_memberships_by_list_id[list2.remote_id].role).to eq("owner")
    end
  end
end

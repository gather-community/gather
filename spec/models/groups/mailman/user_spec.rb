# frozen_string_literal: true

# == Schema Information
#
# Table name: group_mailman_users
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  remote_id  :string           not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
require "rails_helper"

describe Groups::Mailman::User do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_user)
    end
  end

  describe "#syncable?" do
    subject(:syncable) { mm_user.syncable? }

    context "with user record" do
      let(:fake) { false }
      let(:active) { true }
      let(:trait) { :adult }
      let(:user) { create(:user, active ? :active : :inactive, trait, fake: fake) }
      let(:mm_user) { build(:group_mailman_user, user: user) }

      context "with non-fake user" do
        context "with active user" do
          it { is_expected.to be(true) }
        end

        context "with inactive user" do
          let(:active) { false }
          it { is_expected.to be(false) }
        end

        context "with child user" do
          let(:trait) { :child }
          it { is_expected.to be(false) }
        end

        context "full_access_child" do
          let(:trait) { :full_access_child }
          it { is_expected.to be(true) }
        end
      end

      context "when user is fake" do
        let(:fake) { true }
        it { is_expected.to be(false) }
      end
    end

    context "without user record" do
      let(:mm_user) { build(:group_mailman_user, user: nil) }
      it { is_expected.to be(true) }
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
    let!(:list1) { create(:group_mailman_list, remote_id: "a", group: group2) }
    let!(:membership2) { create(:group_membership, group: group2, user: user, kind: "joiner") }

    # Manager but no admin privs
    let!(:group3) { create(:group, availability: "open") }
    let!(:list2) { create(:group_mailman_list, remote_id: "b", group: group3) }
    let!(:membership3) { create(:group_membership, group: group3, user: user, kind: "manager") }

    # Not included b/c no list
    let!(:group4) { create(:group, availability: "open") }
    let!(:membership4) { create(:group_membership, group: group4, user: user) }

    # Manager with admin privs
    let!(:group5) { create(:group, availability: "open") }
    let!(:list3) { create(:group_mailman_list, remote_id: "c", group: group5, managers_can_administer: true) }
    let!(:membership5) { create(:group_membership, group: group5, user: user, kind: "manager") }

    # Not included b/c different user
    let!(:decoy) { create(:group_membership, group: group3) }

    let!(:list_memberships) { mm_user.list_memberships }
    let!(:list_memberships_by_list_id) { list_memberships.group_by(&:list_id) }

    it "returns correct results" do
      expect(list_memberships.size).to eq(4)
      expect(list_memberships_by_list_id[list1.remote_id].map(&:mailman_user).uniq).to eq([mm_user])
      expect(list_memberships_by_list_id[list1.remote_id].map(&:role)).to contain_exactly("member")
      expect(list_memberships_by_list_id[list2.remote_id].map(&:mailman_user).uniq).to eq([mm_user])
      expect(list_memberships_by_list_id[list2.remote_id].map(&:role)).to contain_exactly("member")
      expect(list_memberships_by_list_id[list3.remote_id].map(&:mailman_user).uniq).to eq([mm_user])
      expect(list_memberships_by_list_id[list3.remote_id].map(&:role)).to match_array(%w[owner member])
    end
  end
end

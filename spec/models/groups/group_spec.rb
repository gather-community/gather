# frozen_string_literal: true

# == Schema Information
#
# Table name: groups
#
#  id                         :bigint           not null, primary key
#  availability               :string(10)       default("closed"), not null
#  can_administer_email_lists :boolean          default(FALSE), not null
#  can_moderate_email_lists   :boolean          default(FALSE), not null
#  can_request_jobs           :boolean          default(FALSE), not null
#  cluster_id                 :integer          not null
#  created_at                 :datetime         not null
#  deactivated_at             :datetime
#  description                :string(255)
#  kind                       :string(32)       default("committee"), not null
#  name                       :string(64)       not null
#  updated_at                 :datetime         not null
#
require "rails_helper"

describe Groups::Group do
  it "has a valid factory" do
    create(:group)
  end

  describe "normalization" do
    describe "memberships, kind, and availability" do
      let(:memberships) do
        [
          build(:group_membership, kind: "joiner"),
          build(:group_membership, kind: "manager"),
          build(:group_membership, kind: "opt_out")
        ]
      end
      let(:group) do
        create(:group, memberships: memberships, availability: availability)
      end

      context "for closed group" do
        let(:availability) { "closed" }

        it "is expected to delete opt-outs" do
          expect(group.memberships.map(&:kind)).to match_array(%w[joiner manager])
          expect(group).to be_closed
        end
      end

      context "for everybody group" do
        let(:availability) { "everybody" }

        it "is expected to delete joiner-type memberships" do
          expect(group.memberships.map(&:kind)).to match_array(%w[manager opt_out])
          expect(group).to be_everybody
        end
      end
    end
  end

  describe "validation" do
    describe "name uniqueness in all relevant communities" do
      let(:community1) { create(:community) }
      let(:community2) { create(:community) }

      context "with no existing groups" do
        subject(:group) { build(:group, communities: [community1], name: "Foo") }
        it { is_expected.to be_valid }
      end

      context "with same names and single community groups" do
        let!(:existing) { create(:group, communities: [community1], name: "Foo") }
        subject(:group) { build(:group, communities: [community1], name: "Foo") }
        it { is_expected.to have_errors(name: "has already been taken") }
      end

      context "with same names in cluster but separate communities" do
        let!(:existing) { create(:group, communities: [community1], name: "Foo") }
        subject(:group) { build(:group, communities: [community2], name: "Foo") }
        it { is_expected.to be_valid }
      end

      context "with single community group and multi community group" do
        let!(:existing) { create(:group, communities: [community1], name: "Foo") }
        subject(:group) { build(:group, communities: [community1, community2], name: "Foo") }
        it { is_expected.to have_errors(name: "has already been taken") }
      end
    end

    describe "at least one affiliation" do
      let(:community1) { create(:community) }

      context "with one affiliation" do
        subject(:group) { build(:group, communities: [community1]) }
        it { is_expected.to be_valid }
      end

      context "with no affiliations" do
        let(:group) { create(:group, communities: [community1]) }

        before do
          group.assign_attributes(community_ids: [])
        end

        it { is_expected.to have_errors(base: "Please select at least one community") }
      end
    end

    describe "no members from non-affiliated communities" do
      let(:community1) { create(:community) }
      let(:community2) { create(:community) }
      let(:user1) { create(:user, community: community1) }
      let(:user2) { create(:user, community: community2) }

      context "with no members" do
        subject(:group) { build(:group, communities: [community1], joiners: []) }
        it { is_expected.to be_valid }
      end

      context "with members from affiliated communities only" do
        subject(:group) { build(:group, communities: [community1, community2], joiners: [user1, user2]) }
        it { is_expected.to be_valid }
      end

      context "with member from non-affiliated community" do
        subject(:group) { build(:group, communities: [community1], joiners: [user1, user2]) }
        it { expect(group.memberships[1]).to have_errors(user_id: "Not from an affiliated community") }
      end
    end

    describe "clear_mailman_list_if_empty_name" do
      let(:group) { create(:group) }

      it "should remove list entirely if name not filled out and didn't pre-exist" do
        group.build_mailman_list(name: "")
        group.save
        expect(group.mailman_list).to be_nil
      end
    end
  end

  describe "member?" do
    let(:group) { create(:group, availability: availability) }
    let!(:user) { create(:user) }
    let!(:membership) { create(:group_membership, group: group, user: user, kind: mbr_kind) if mbr_kind }
    subject(:is_member) { group.member?(user) }

    context "with everybody group" do
      let(:availability) { "everybody" }

      context "with user with no membership" do
        let(:mbr_kind) { nil }
        it { is_expected.to be(true) }
      end

      context "with user with manager membership" do
        let(:mbr_kind) { "manager" }
        it { is_expected.to be(true) }
      end

      context "with user with opt-out membership" do
        let(:mbr_kind) { "opt_out" }
        it { is_expected.to be(false) }
      end
    end

    context "with non-everybody group" do
      let(:availability) { "closed" }

      context "with user with no membership" do
        let(:mbr_kind) { nil }
        it { is_expected.to be(false) }
      end

      context "with user with manager membership" do
        let(:mbr_kind) { "manager" }
        it { is_expected.to be(true) }
      end

      context "with user with joiner membership" do
        let(:mbr_kind) { "joiner" }
        it { is_expected.to be(true) }
      end
    end
  end

  describe "#join" do
    let(:group) { create(:group, availability: availability) }
    let!(:user) { create(:user) }
    let!(:membership) { create(:group_membership, group: group, user: user, kind: mbr_kind) if mbr_kind }

    before do
      group.join(user)
    end

    context "with everybody group" do
      let(:availability) { "everybody" }

      context "with user with no membership" do
        let(:mbr_kind) { nil }
        it { expect_no_membership }
      end

      context "with user with manager membership" do
        let(:mbr_kind) { "manager" }
        it { expect_single_membership(user, group, "manager") }
      end

      context "with user with opt-out membership" do
        let(:mbr_kind) { "opt_out" }
        it { expect_no_membership }
      end
    end

    context "with non-everybody group" do
      let(:availability) { "closed" }

      context "with user with no membership" do
        let(:mbr_kind) { nil }
        it { expect_single_membership(user, group, "joiner") }
      end

      context "with user with manager membership" do
        let(:mbr_kind) { "manager" }
        it { expect_single_membership(user, group, "manager") }
      end

      context "with user with joiner membership" do
        let(:mbr_kind) { "joiner" }
        it { expect_single_membership(user, group, "joiner") }
      end
    end
  end

  describe "#leave" do
    let(:group) { create(:group, availability: availability) }
    let!(:user) { create(:user) }
    let!(:membership) { create(:group_membership, group: group, user: user, kind: mbr_kind) if mbr_kind }

    before do
      group.leave(user)
    end

    context "with everybody group" do
      let(:availability) { "everybody" }

      context "with user with no membership" do
        let(:mbr_kind) { nil }
        it { expect_single_membership(user, group, "opt_out") }
      end

      context "with user with manager membership" do
        let(:mbr_kind) { "manager" }
        it { expect_no_membership }
      end

      context "with user with opt-out membership" do
        let(:mbr_kind) { "opt_out" }
        it { expect_single_membership(user, group, "opt_out") }
      end
    end

    context "with non-everybody group" do
      let(:availability) { "closed" }

      context "with user with no membership" do
        let(:mbr_kind) { nil }
        it { expect_no_membership }
      end

      context "with user with manager membership" do
        let(:mbr_kind) { "manager" }
        it { expect_no_membership }
      end

      context "with user with joiner membership" do
        let(:mbr_kind) { "joiner" }
        it { expect_no_membership }
      end
    end
  end

  describe "#members, #computed_memberships, and .with_member_counts" do
    let!(:users) { create_list(:user, 8) }
    let!(:external_decoy_user) { create(:user, community: create(:community)) }
    let!(:child) { create(:user, :child, guardians: [users[0]]) }
    let!(:regular_group) do
      create(:group, name: "Alpha", availability: "open", memberships: [
        build(:group_membership, user: users[0], kind: "joiner"),
        build(:group_membership, user: users[1], kind: "joiner"),
        build(:group_membership, user: users[2], kind: "manager")
      ])
    end
    let!(:everybody_group) do
      create(:group, name: "Bravo", availability: "everybody", memberships: [
        build(:group_membership, user: users[0], kind: "opt_out"),
        build(:group_membership, user: users[4], kind: "opt_out"),
        build(:group_membership, user: users[5], kind: "manager")
      ])
    end

    it "is correct with and without user_eager_load" do
      groups = described_class.by_name.with_member_counts.to_a
      expect(groups[0].member_count).to eq(3)
      expect(groups[0].members).to contain_exactly(users[0], users[1], users[2])
      expect(groups[0].members(user_eager_load: :group_mailman_user))
        .to contain_exactly(users[0], users[1], users[2])
      expect(groups[0].computed_memberships.size).to eq(3)
      summary = groups[0].computed_memberships(user_eager_load: :group_mailman_user).map do |m|
        [m.user_id, m.group_id, m.kind]
      end
      expect(summary).to contain_exactly(
        [users[0].id, groups[0].id, "joiner"],
        [users[1].id, groups[0].id, "joiner"],
        [users[2].id, groups[0].id, "manager"]
      )

      expect(groups[1].member_count).to eq(6)
      expect(groups[1].members).to contain_exactly(users[1], users[2], users[3], users[5], users[6], users[7])
      expect(groups[1].members(user_eager_load: :group_mailman_user))
        .to contain_exactly(users[1], users[2], users[3], users[5], users[6], users[7])
      expect(groups[1].computed_memberships.size).to eq(8)
      summary = groups[1].computed_memberships(user_eager_load: :group_mailman_user).map do |m|
        [m.user_id, m.group_id, m.kind]
      end
      expect(summary).to contain_exactly(
        [users[0].id, groups[1].id, "opt_out"],
        [users[1].id, groups[1].id, "joiner"],
        [users[2].id, groups[1].id, "joiner"],
        [users[3].id, groups[1].id, "joiner"],
        [users[4].id, groups[1].id, "opt_out"],
        [users[5].id, groups[1].id, "manager"],
        [users[6].id, groups[1].id, "joiner"],
        [users[7].id, groups[1].id, "joiner"]
      )
    end
  end

  describe "destroy" do
    let!(:group) { create(:group) }

    context "with various associations" do
      let!(:membership) { create(:group_membership, group: group) }
      let!(:affiliation) { group.affiliations.first }
      let!(:job) { create(:work_job, requester: group) }
      let!(:mailman_list) { create(:group_mailman_list, group: group) }
      let!(:item_group) { create(:gdrive_item_group, group: group) }

      it "cascades and nullifies appropriately" do
        group.reload.destroy
        expect(Groups::Membership.exists?(membership.id)).to be(false)
        expect(Groups::Affiliation.exists?(affiliation.id)).to be(false)
        expect(job.reload.requester).to be_nil
        expect(Groups::Mailman::List.exists?(mailman_list.id)).to be(false)
        expect(GDrive::ItemGroup.exists?(item_group.id)).to be(false)
      end
    end
  end

  def expect_no_membership
    expect(Groups::Membership.count).to eq(0)
  end

  def expect_single_membership(user, group, kind)
    expect(Groups::Membership.count).to eq(1)
    expect(Groups::Membership.first).to have_attributes(user: user, group: group, kind: kind)
  end
end

# frozen_string_literal: true

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
        subject(:group) { build(:group, communities: [community1], users: []) }
        it { is_expected.to be_valid }
      end

      context "with members from affiliated communities only" do
        subject(:group) { build(:group, communities: [community1, community2], users: [user1, user2]) }
        it { is_expected.to be_valid }
      end

      context "with member from non-affiliated community" do
        subject(:group) { build(:group, communities: [community1], users: [user1, user2]) }
        it { expect(group.memberships[1]).to have_errors(user_id: "Not from an affiliated community") }
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
  end

  describe "#members and .with_member_counts" do
    let!(:users) { create_list(:user, 8) }
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

    it "is correct" do
      groups = described_class.by_name.with_member_counts.to_a
      expect(groups[0].member_count).to eq(3)
      expect(groups[0].members).to contain_exactly(users[0], users[1], users[2])
      expect(groups[1].member_count).to eq(6)
      expect(groups[1].members).to contain_exactly(users[1], users[2], users[3], users[5], users[6], users[7])
    end
  end

  def expect_no_membership
    expect_no_membership
  end

  def expect_single_membership(user, group, kind)
    expect(Groups::Membership.count).to eq(1)
    expect(Groups::Membership.first).to have_attributes(user: user, group: group, kind: kind)
  end
end

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
  end
end

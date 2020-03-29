# frozen_string_literal: true

require "rails_helper"

describe Groups::User do
  describe "#computed_memberships" do
    let!(:group1) { create(:group, availability: "everybody") }
    let!(:group2) { create(:group, availability: "everybody") }
    let!(:group3) { create(:group, availability: "everybody") }
    let!(:group4) { create(:group, availability: "open") }
    let!(:decoy) { create(:group, availability: "open") }
    subject(:computed_memberships) { described_class.new(user: user).computed_memberships }

    context "with user in community" do
      let!(:user) { create(:user) }
      let!(:memberships) do
        [
          create(:group_membership, group: group2, user: user, kind: "manager"),
          create(:group_membership, group: group3, user: user, kind: "opt_out"),
          create(:group_membership, group: group4, user: user, kind: "manager")
        ]
      end
      subject(:computed_memberships_by_group) { computed_memberships.group_by(&:group) }

      it "returns correct list" do
        expect(computed_memberships.size).to eq(4)
        expect(computed_memberships_by_group[group1].map(&:kind).uniq).to eq(["joiner"])
        expect(computed_memberships_by_group[group2].map(&:kind).uniq).to eq(["manager"])
        expect(computed_memberships_by_group[group3].map(&:kind).uniq).to eq(["opt_out"])
        expect(computed_memberships_by_group[group4].map(&:kind).uniq).to eq(["manager"])
        expect(computed_memberships_by_group[group1].map(&:persisted?).uniq).to eq([false])
        expect(computed_memberships_by_group[group2].map(&:persisted?).uniq).to eq([true])
        expect(computed_memberships_by_group[group3].map(&:persisted?).uniq).to eq([true])
        expect(computed_memberships_by_group[group4].map(&:persisted?).uniq).to eq([true])
      end
    end

    context "with user in other community" do
      let!(:user) { create(:user, community: create(:community)) }

      it "returns empty list" do
        expect(computed_memberships).to be_empty
      end
    end
  end
end

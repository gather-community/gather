# frozen_string_literal: true

require "rails_helper"

describe Groups::Group do
  it "has a valid factory" do
    create(:group)
  end

  describe "normalization" do
    describe "memberships" do
      let(:memberships) do
        [build(:group_membership, kind: "member"), build(:group_membership, kind: "manager")]
      end
      let(:group) { create(:group, memberships: memberships) }

      context "for normal group" do
        it "is expected to have saved memberships" do
          expect(group.memberships.map(&:kind)).to eq(%w[member manager])
          expect(Groups::Membership.count).to eq(2)
        end
      end

      context "for broadcast group" do
        it "is expected to delete non-manager memberships" do
          group.update!(kind: "broadcast")
          expect(group.memberships.map(&:kind)).to eq(["manager"])
          expect(Groups::Membership.count).to eq(1)
        end
      end
    end
  end
end

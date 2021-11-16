# frozen_string_literal: true

require "rails_helper"

describe Role do
  context "when two people in different clusters have the same role" do
    let(:cluster1) { create(:cluster) }
    let(:cluster2) { create(:cluster) }
    let!(:user1) { ActsAsTenant.with_tenant(cluster1) { create(:meals_coordinator) } }
    let!(:user2) { ActsAsTenant.with_tenant(cluster2) { create(:meals_coordinator) } }

    it "removing one role doesn't affect the other one" do
      ActsAsTenant.with_tenant(cluster1) { user1.remove_role(:meals_coordinator) }
      expect(Role.count).to eq(1)
      ActsAsTenant.with_tenant(cluster2) { expect(user2.has_role?(:meals_coordinator)).to be(true) }
    end
  end
end

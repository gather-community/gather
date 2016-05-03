require 'rails_helper'

describe Reservation::ResourcePolicy do
  describe "scope" do
    let!(:resource1) { create(:resource) }
    let!(:resource2) { create(:resource) }
    let!(:resource3) { create(:resource) }
    let!(:protocol1) { create(:reservation_protocol, resources: [resource1], other_communities: "forbidden") }
    let!(:protocol2) { create(:reservation_protocol, resources: [resource2], other_communities: "read_only") }
    let!(:insider) { create(:user) }
    let!(:outsider_household) { create(:household, community: create(:community)) }
    let!(:outsider) { create(:user, household: outsider_household) }

    it "for outsiders, returns only non-forbidden resources" do
      permitted = Reservation::ResourcePolicy::Scope.new(outsider, Reservation::Resource.all).resolve
      expect(permitted).to contain_exactly(resource2, resource3)
    end

    it "for insiders, returns all resources" do
      permitted = Reservation::ResourcePolicy::Scope.new(insider, Reservation::Resource.all).resolve
      expect(permitted).to contain_exactly(resource1, resource2, resource3)
    end
  end
end

require 'rails_helper'

describe Reservations::ResourcePolicy do
  describe "permissions" do
    include_context "policy objs"

    let(:resource) { Reservations::Resource.new(community: community) }
    let(:record) { resource }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits for commmunity admins and denies for other admins, users, and billers"
    end
  end

  describe "scope" do
    let!(:resource1) { create(:resource) }
    let!(:resource2) { create(:resource) }
    let!(:resource3) { create(:resource) }
    let!(:resource4) { create(:resource, :inactive) }
    let!(:protocol1) { create(:reservation_protocol, resources: [resource1], other_communities: "forbidden") }
    let!(:protocol2) { create(:reservation_protocol, resources: [resource2], other_communities: "read_only") }
    let!(:insider) { create(:user) }
    let!(:admin) { create(:admin) }
    let!(:outsider_household) { create(:household, community: create(:community)) }
    let!(:outsider) { create(:user, household: outsider_household) }

    it "for outsiders, returns only non-forbidden resources" do
      permitted = Reservations::ResourcePolicy::Scope.new(outsider, Reservations::Resource.all).resolve
      expect(permitted).to contain_exactly(resource2, resource3)
    end

    it "for insiders, returns all active resources" do
      permitted = Reservations::ResourcePolicy::Scope.new(insider, Reservations::Resource.all).resolve
      expect(permitted).to contain_exactly(resource1, resource2, resource3)
    end

    it "for admins, returns all resources" do
      permitted = Reservations::ResourcePolicy::Scope.new(admin, Reservations::Resource.all).resolve
      expect(permitted).to contain_exactly(resource1, resource2, resource3, resource4)
    end
  end

  describe "permitted attributes" do
    subject { Reservations::ResourcePolicy.new(User.new, Reservations::Resource.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:default_calendar_view, :guidelines, :abbrv, :name,
        :meal_hostable, :photo, :photo_tmp_id, :photo_destroy)
    end
  end
end

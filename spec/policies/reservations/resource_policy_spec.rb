# frozen_string_literal: true

require "rails_helper"

describe Reservations::ResourcePolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:resource) { build(:resource, community: community) }
    let(:record) { resource }

    permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, :deactivate? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins but not regular users"
    end

    permissions :destroy? do
      it "denies if there are existing reservations" do
        resource.save!
        create(:reservation, resource: resource)
        expect(subject).not_to permit(admin, resource)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Reservations::Resource }
    let!(:resource1) { create(:resource) }
    let!(:resource2) { create(:resource) }
    let!(:resource3) { create(:resource) }
    let!(:resource4) { create(:resource, :inactive) }
    let!(:protocol1) { create(:reservation_protocol, resources: [resource1], other_communities: "forbidden") }
    let!(:protocol2) { create(:reservation_protocol, resources: [resource2], other_communities: "read_only") }

    context "for insiders, returns all active resources" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(resource1, resource2, resource3) }
    end

    context "for outsiders, returns only non-forbidden resources" do
      let(:actor) { userB }
      it { is_expected.to contain_exactly(resource2, resource3) }
    end

    context "for admins, returns all resources" do
      let(:actor) { admin }
      it { is_expected.to contain_exactly(resource1, resource2, resource3, resource4) }
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

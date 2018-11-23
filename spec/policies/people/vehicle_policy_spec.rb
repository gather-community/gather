# frozen_string_literal: true

require "rails_helper"

describe People::VehiclePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:household) { build(:household, community: community) }
    let(:vehicle) { build(:vehicle, household: household) }
    let(:record) { vehicle }

    permissions :index? do
      it_behaves_like "permits cluster and super admins"
      it_behaves_like "permits users in community only"
    end

    permissions :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "forbids all"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { People::Vehicle }
    let(:objs_in_community) { create_list(:vehicle, 2, household: user.household) }
    let(:objs_in_cluster) { create_list(:vehicle, 2, household: userB.household) }

    it_behaves_like "allows regular users in community"
  end
end

require 'rails_helper'

describe People::VehiclePolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:household) { build(:household, community: community) }
    let(:vehicle) { build(:vehicle, household: household) }
    let(:record) { vehicle }

    permissions :index? do
      it_behaves_like "permits users in community only"
    end

    permissions :show?, :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "forbids all"
    end
  end

  describe "scope" do
    let(:vehicle1) { create(:vehicle, household: user.household) }
    let(:vehicle2) { create(:vehicle, household: user.household) }
    let(:vehicle3) { create(:vehicle, household: user_in_cmtyB.household) }
    subject { People::VehiclePolicy::Scope.new(actor, People::Vehicle.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, user_in_cmtyB, vehicle1, vehicle2, vehicle3)
    end

    context "for regular users" do
      let(:actor) { user }
      it { pp People::Vehicle.all.to_a; pp user; pp user.household; is_expected.to contain_exactly(vehicle1, vehicle2) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(vehicle1, vehicle2, vehicle3) }
    end
  end
end

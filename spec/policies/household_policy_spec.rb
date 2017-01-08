require 'rails_helper'

describe HouseholdPolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:record) { household }

    shared_examples_for "admins and members of household" do
      it "grants access for regular users to own household" do
        expect(subject).to permit(user, user.household)
      end

      it "denies access for regular users to other households" do
        expect(subject).not_to permit(user, Household.new)
      end

      it "grants access to admins" do
        expect(subject).to permit(admin, user.household)
      end
    end

    permissions :index?, :show? do
      it_behaves_like "grants access to users in cluster"
    end

    permissions :new?, :create?, :activate?, :deactivate?, :administer? do
      it_behaves_like "admins only"
    end

    permissions :edit?, :update? do
      it_behaves_like "admins and members of household"

      it "denies access to billers" do
        expect(subject).not_to permit(biller, user.household)
      end
    end

    permissions :accounts? do
      it_behaves_like "admins and members of household"

      it "grants access to billers" do
        expect(subject).to permit(biller, user.household)
      end
    end

    permissions :change_community? do
      it_behaves_like "cluster admins only"
    end

    permissions :destroy? do
      shared_examples_for "full denial" do
        it "denies access to admins" do
          expect(subject).not_to permit(admin, household)
        end

        it "denies access to billers" do
          expect(subject).not_to permit(biller, household)
        end
      end

      context "with user" do
        it_behaves_like "full denial"
      end

      context "with assignment" do
        before { household.users.first.assignments.build }
        it_behaves_like "full denial"
      end

      context "with signup" do
        before { household.signups.build }
        it_behaves_like "full denial"
      end

      context "with account" do
        before { household.accounts.build }
        it_behaves_like "full denial"
      end

      context "without any of the above" do
        before { household.users = [] }
        it_behaves_like "admins only"
      end
    end
  end

  describe "allowed_community_changes" do
    before do
      [cluster, clusterB, community, communityB, communityX].each(&:save!)
    end

    it "returns empty set for admins and lower" do
      expect(HouseholdPolicy.new(admin, Household).allowed_community_changes).to eq []
    end

    it "returns cluster communities for cluster admins" do
      expect(HouseholdPolicy.new(cluster_admin, Household).allowed_community_changes).to(
        contain_exactly(community, communityB))
    end

    it "returns all communities for super admins" do
      expect(HouseholdPolicy.new(super_admin, Household).allowed_community_changes).to(
        contain_exactly(community, communityB, communityX))
    end
  end

  describe "scope" do
    let!(:user) { create(:user) }
    let!(:household2) { create(:household) }

    it "returns all households for regular users" do
      permitted = HouseholdPolicy::Scope.new(user, Household.all).resolve
      expect(permitted).to contain_exactly(user.household, household2)
    end
  end

  describe "permitted attributes" do
    let(:basic_attribs) { [:name, :garage_nums,
      {vehicles_attributes: [:id, :make, :model, :color, :_destroy]},
      {emergency_contacts_attributes: [:id, :name, :relationship, :main_phone, :alt_phone,
        :email, :location, :_destroy]}] }
    let(:admin_attribs) { basic_attribs.concat([:unit_num, :old_id, :old_name]) }
    let(:cluster_admin_attribs) { admin_attribs << :community_id }

    subject { HouseholdPolicy.new(user, household).permitted_attributes }

    context "regular user" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(*basic_attribs)
      end
    end

    context "admin" do
      let(:user) { admin }

      it "should allow admin and basic attribs" do
        expect(subject).to contain_exactly(*admin_attribs)
      end
    end

    context "cluster admin" do
      let(:user) { cluster_admin }

      it "should allow all attribs" do
        expect(subject).to contain_exactly(*cluster_admin_attribs)
      end
    end
  end
end

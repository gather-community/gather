require 'rails_helper'

describe HouseholdPolicy do
  describe "permissions" do
    include_context "policy objs"

    let(:record) { household }

    permissions :index?, :show? do
      it_behaves_like "grants access to users in cluster"
    end

    permissions :new?, :create?, :edit?, :update?, :activate?, :deactivate? do
      it_behaves_like "admins only"
    end

    permissions :accounts? do
      it "grants access for regular users to own household" do
        expect(subject).to permit(user, user.household)
      end

      it "denies access for regular users to other households" do
        expect(subject).not_to permit(user, Household.new)
      end
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

  describe "scope" do
    let!(:user) { create(:user) }
    let!(:household2) { create(:household) }

    it "returns all households for regular users" do
      permitted = HouseholdPolicy::Scope.new(user, Household.all).resolve
      expect(permitted).to contain_exactly(user.household, household2)
    end
  end

  describe "permitted attributes" do
    subject { HouseholdPolicy.new(User.new, Household.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:name, :community_id, :unit_num, :old_id, :old_name,
        vehicles_attributes: [:id, :make, :model, :color, :_destroy])
    end
  end
end

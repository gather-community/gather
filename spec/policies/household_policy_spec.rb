require 'rails_helper'

describe HouseholdPolicy do
  describe "permissions" do
    include_context "policy objs"

    shared_examples_for "admins but not regular users" do
      it "grants access to admins" do
        expect(subject).to permit(admin, household)
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(user, household)
      end
    end

    shared_examples_for "admins only" do
      it_behaves_like "admins but not regular users"

      it "denies access to billers" do
        expect(subject).not_to permit(biller, household)
      end
    end

    permissions :index?, :show? do
      it_behaves_like "admins but not regular users"

      it "grants access to billers" do
        expect(subject).to permit(biller, household)
      end
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
    let!(:admin) { create(:admin) }
    let!(:household2) { create(:household) }

    it "returns all households for admins" do
      permitted = HouseholdPolicy::Scope.new(admin, Household.all).resolve
      expect(permitted).to contain_exactly(admin.household, household2)
    end

    it "returns no households for regular users" do
      permitted = HouseholdPolicy::Scope.new(User.new, Household.all).resolve
      expect(permitted).to eq([])
    end
  end

  describe "permitted attributes" do
    subject { HouseholdPolicy.new(User.new, Household.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:name, :community_id, :unit_num, :old_id, :old_name)
    end
  end
end

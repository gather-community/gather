require 'rails_helper'

describe AccountPolicy do

  describe "permissions" do
    include_context "policy objs"

    let(:account) { Account.new }
    let(:account_owner) { User.new(household: Household.new) }

    before do
      allow(account).to receive(:household).and_return(account_owner.household)
      allow(account).to receive(:community).and_return(community)
    end

    shared_examples_for :admin_or_biller do
      it "grants access to admins" do
        expect(subject).to permit(admin, Account)
      end

      it "grants access to biller" do
        expect(subject).to permit(biller, Account)
      end

      it "denies access to normal user" do
        expect(subject).not_to permit(user, Account)
      end
    end

    shared_examples_for :admin_or_biller_with_community do
      it "grants access to admins from community" do
        expect(subject).to permit(admin, account)
      end

      it "grants access to billers from community" do
        expect(subject).to permit(admin, account)
      end

      it "denies access to admins from outside community" do
        expect(subject).not_to permit(outside_admin, account)
      end

      it "denies access to billers from outside community" do
        expect(subject).not_to permit(outside_biller, account)
      end

      it "denies access to regular user" do
        expect(subject).not_to permit(user, account)
      end
    end

    permissions :index?, :apply_late_fees? do
      it_behaves_like :admin_or_biller
    end

    permissions :show? do
      it_behaves_like :admin_or_biller_with_community

      it "grants access to owner of account" do
        expect(subject).to permit(account_owner, account)
      end

      context "with inactive owner" do
        before { account_owner.deactivated_at = Time.now }

        it "still grants access" do
          expect(subject).to permit(account_owner, account)
        end
      end
    end

    permissions :new?, :create?, :destroy? do
      it "denies all" do
        expect(subject).not_to permit(admin, account)
      end
    end

    permissions :edit?, :update? do
      it_behaves_like :admin_or_biller_with_community
    end
  end

  describe "scope" do

    let!(:community) { create(:community) }
    let!(:other_community) { create(:community) }
    let!(:account1) { create(:account, community: community) }
    let!(:account2) { create(:account, community: community, household: user.household) }
    let!(:account3) { create(:account, community: other_community, household: user.household) }
    let!(:account4) { create(:account, community: other_community) }

    shared_examples_for :admin_or_biller do
      it "returns all accounts from own community or household only" do
        permitted = AccountPolicy::Scope.new(user, Account.all).resolve
        expect(permitted).to contain_exactly(account1, account2, account3)
      end
    end

    context "admin" do
      let!(:user) { create(:user, admin: true) }
      it_behaves_like :admin_or_biller
    end

    context "biller" do
      let!(:user) { create(:user, biller: true) }
      it_behaves_like :admin_or_biller
    end

    context "regular user" do
      let!(:user) { create(:user) }

      it "returns all accounts from own household only" do
        permitted = AccountPolicy::Scope.new(user, Account.all).resolve
        expect(permitted).to contain_exactly(account2, account3)
      end
    end
  end

  describe "permitted_attributes" do
    let(:user) { User.new }
    let(:policy) { AccountPolicy.new(user, Account) }

    it "should allow only credit_limit" do
      expect(policy.permitted_attributes).to contain_exactly(:credit_limit)
    end
  end
end

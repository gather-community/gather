require 'rails_helper'

module Billing
  describe AccountPolicy do
    describe "permissions" do
      include_context "policy objs"

      let(:model) { Account }
      let(:account) { Account.new }
      let(:record) { account }
      let(:account_owner) { User.new(household: Household.new) }

      before do
        allow(account).to receive(:household).and_return(account_owner.household)
        allow(account).to receive(:community).and_return(community)
      end

      permissions :index?, :apply_late_fees? do
        it_behaves_like "permits admins or special role but not regular users", :biller
      end

      permissions :show? do
        it_behaves_like "permits admins or special role but not regular users", :biller

        it "permits owner of account" do
          expect(subject).to permit(account_owner, account)
        end

        context "with inactive owner" do
          before { account_owner.deactivated_at = Time.current }

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
        it_behaves_like "permits admins or special role but not regular users", :biller
      end
    end

    describe "scope" do

      let!(:community) { create(:community) }
      let!(:other_community) { create(:community) }
      let!(:account1) { create(:account, community: community) }
      let!(:account2) { create(:account, community: community, household: user.household) }
      let!(:account3) { create(:account, community: other_community, household: user.household) }
      let!(:account4) { create(:account, community: other_community) }
      let(:permitted) { AccountPolicy::Scope.new(user, Account.all).resolve }

      shared_examples_for :admin_or_biller do
        it "returns all accounts from own community or household only" do
          expect(permitted).to contain_exactly(account1, account2, account3)
        end
      end

      context "admin" do
        let!(:user) { create(:admin) }
        it_behaves_like :admin_or_biller
      end

      context "biller" do
        let!(:user) { create(:biller) }
        it_behaves_like :admin_or_biller
      end

      context "regular user" do
        let!(:user) { create(:user) }

        it "returns all accounts from own household only" do
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
end

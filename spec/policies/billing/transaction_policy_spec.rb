require 'rails_helper'

module Billing
  describe TransactionPolicy do

    describe "permissions" do
      include_context "policy objs"

      let(:transaction) { Transaction.new }

      permissions :index? do
        it "grants access to everyone" do
          expect(subject).to permit(user, Transaction)
        end
      end

      permissions :new?, :create? do
        it "grants access to admins" do
          expect(subject).to permit(admin, Transaction)
        end

        it "grants access to billers" do
          expect(subject).to permit(biller, Transaction)
        end

        it "denies access to normal user" do
          expect(subject).not_to permit(user, Transaction)
        end
      end

      permissions :show?, :edit?, :update?, :destroy? do
        it "denies all" do
          expect(subject).not_to permit(admin, transaction)
        end
      end
    end

    describe "scope" do

      let!(:community) { create(:community) }
      let!(:other_community) { create(:community) }
      let!(:account1) { create(:account, community: community) }
      let!(:account2) { create(:account, community: community, household: user.household) }
      let!(:account3) { create(:account, community: other_community, household: user.household) }
      let!(:account4) { create(:account, community: other_community) }
      let!(:transaction1) { create(:transaction, account: account1) }
      let!(:transaction2) { create(:transaction, account: account2) }
      let!(:transaction3) { create(:transaction, account: account3) }
      let!(:transaction4) { create(:transaction, account: account4) }

      shared_examples_for :admin_or_biller do
        it "returns all transactions from own community or household only" do
          permitted = TransactionPolicy::Scope.new(user, Transaction.all).resolve
          expect(permitted).to contain_exactly(transaction1, transaction2, transaction3)
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

        it "returns all transactions from own household only" do
          permitted = TransactionPolicy::Scope.new(user, Transaction.all).resolve
          expect(permitted).to contain_exactly(transaction2, transaction3)
        end
      end
    end

    describe "permitted attributes" do
      subject { TransactionPolicy.new(User.new, Transaction.new).permitted_attributes }

      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:incurred_on, :code, :description, :amount)
      end
    end
  end
end

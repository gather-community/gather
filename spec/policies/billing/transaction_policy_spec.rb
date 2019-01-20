# frozen_string_literal: true

require "rails_helper"

describe Billing::TransactionPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:transaction) { create(:transaction) }
    let(:record) { transaction }

    permissions :index? do
      it "permits everyone" do
        expect(subject).to permit(user, Billing::Transaction)
      end
    end

    permissions :new?, :create? do
      it_behaves_like "permits admins or special role but not regular users", :biller
    end

    permissions :show?, :edit?, :update?, :destroy? do
      it "denies all" do
        expect(subject).not_to permit(admin, transaction)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Billing::Transaction }
    let!(:account1) { create(:account) }
    let!(:account2) { create(:account, household: actor.household) }
    let!(:account3) { create(:account, community: communityB, household: actor.household) }
    let!(:account4) { create(:account, community: communityB) }
    let!(:transaction1) { create(:transaction, account: account1) }
    let!(:transaction2) { create(:transaction, account: account2) }
    let!(:transaction3) { create(:transaction, account: account3) }
    let!(:transaction4) { create(:transaction, account: account4) }

    shared_examples_for :admin_or_biller do
      it "returns all transactions from own community or household only" do
        is_expected.to contain_exactly(transaction1, transaction2, transaction3)
      end
    end

    context "admin" do
      let(:actor) { admin }
      it_behaves_like :admin_or_biller
    end

    context "biller" do
      let(:actor) { biller }
      it_behaves_like :admin_or_biller
    end

    context "regular user returns all transactions from own household only" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(transaction2, transaction3) }
    end
  end

  describe "permitted attributes" do
    subject { Billing::TransactionPolicy.new(User.new, Billing::Transaction.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:incurred_on, :code, :description, :amount)
    end
  end
end

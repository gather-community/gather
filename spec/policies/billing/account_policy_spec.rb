# frozen_string_literal: true

require "rails_helper"

describe Billing::AccountPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:account) { Billing::Account.new }
    let(:record) { account }
    let(:account_owner) { User.new(household: Household.new) }

    before do
      allow(account).to receive(:household).and_return(account_owner.household)
      allow(account).to receive(:community).and_return(community)
    end

    permissions :index?, :apply_late_fees?, :add_txn? do
      it_behaves_like "permits admins or special role but not regular users", :biller
    end

    permissions :yours? do
      it_behaves_like "permits active and inactive users"
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
    include_context "policy scopes"
    let(:klass) { Billing::Account }
    let!(:account1) { create(:account) }
    let!(:account2) { create(:account, household: actor.household) }
    let!(:account3) { create(:account, community: communityB, household: actor.household) }
    let!(:account4) { create(:account, community: communityB) }

    shared_examples_for :admin_or_biller do
      it "returns all accounts from own community or household only" do
        is_expected.to contain_exactly(account1, account2, account3)
      end
    end

    context "cluster_admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(account1, account2, account3, account4) }
    end

    context "admin" do
      let(:actor) { admin }
      it_behaves_like :admin_or_biller
    end

    context "biller" do
      let(:actor) { biller }
      it_behaves_like :admin_or_biller
    end

    context "regular user returns all accounts from own household only" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(account2, account3) }
    end
  end

  describe "permitted_attributes" do
    let(:user) { User.new }
    let(:policy) { Billing::AccountPolicy.new(user, Billing::Account) }

    it "should allow only credit_limit" do
      expect(policy.permitted_attributes).to contain_exactly(:credit_limit)
    end
  end

  describe "#exportable_attributes" do
    include_context "policy permissions"

    let(:actor) { create(:biller) }
    let(:sample_account) { double(community: community) }
    subject(:exportable) { described_class.new(actor, sample_account).exportable_attributes }

    context "with single community" do
      it do
        is_expected.to match_array(
          %i[number household_id household_name balance_due current_balance credit_limit
             last_statement_id last_statement_on due_last_statement total_new_charges
             total_new_credits created_at]
        )
      end
    end

    context "with multiple communities" do
      let!(:community2) { create(:community) }
      it do
        is_expected.to match_array(
          %i[number community_id community_name
             household_id household_name balance_due current_balance credit_limit
             last_statement_id last_statement_on due_last_statement total_new_charges
             total_new_credits created_at]
        )
      end
    end
  end
end

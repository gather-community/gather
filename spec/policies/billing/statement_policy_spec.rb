# frozen_string_literal: true

require "rails_helper"

describe Billing::StatementPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:statement) { Billing::Statement.new }
    let(:record) { statement }
    let(:statement_owner) { User.new(household: Household.new) }

    before do
      allow(statement).to receive(:household).and_return(statement_owner.household)
      allow(statement).to receive(:community).and_return(community)
    end

    permissions :index?, :generate? do
      it_behaves_like "permits admins or special role but not regular users", :biller
    end

    permissions :show? do
      it_behaves_like "permits admins or special role but not regular users", :biller

      it "permits owner of statement" do
        expect(subject).to permit(statement_owner, statement)
      end

      context "with inactive owner" do
        before { statement_owner.deactivated_at = Time.current }

        it "still grants access" do
          expect(subject).to permit(statement_owner, statement)
        end
      end
    end

    permissions :new?, :create?, :edit?, :update?, :destroy? do
      it "denies all" do
        expect(subject).not_to permit(admin, account)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Billing::Statement }
    let!(:account1) { create(:account) }
    let!(:account2) { actor.household.accounts[0] }
    let!(:account3) { create(:account, community: communityB, household: actor.household) }
    let!(:account4) { create(:account, community: communityB) }
    let!(:statement1) { create(:statement, account: account1) }
    let!(:statement2) { create(:statement, account: account2) }
    let!(:statement3) { create(:statement, account: account3) }
    let!(:statement4) { create(:statement, account: account4) }

    shared_examples_for "returns statements from community or household" do
      it "returns all statements from own community or household only" do
        is_expected.to contain_exactly(statement1, statement2, statement3)
      end
    end

    context "cluster_admin" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(statement1, statement2, statement3, statement4) }
    end

    context "admin" do
      let(:actor) { admin }
      it_behaves_like "returns statements from community or household"
    end

    context "biller" do
      let(:actor) { biller }
      it_behaves_like "returns statements from community or household"
    end

    context "regular user returns all statements from own household only" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(statement2, statement3) }
    end
  end
end

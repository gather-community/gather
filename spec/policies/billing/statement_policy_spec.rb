require 'rails_helper'

module Billing
  describe StatementPolicy do
    describe "permissions" do
      include_context "policy objs"

      let(:statement) { Statement.new }
      let(:record) { statement }
      let(:statement_owner) { User.new(household: Household.new) }

      before do
        allow(statement).to receive(:household).and_return(statement_owner.household)
        allow(statement).to receive(:community).and_return(community)
      end

      permissions :index?, :generate? do
        it_behaves_like "permits admins or billers but not regular users"
      end

      permissions :show? do
        it_behaves_like "permits admins or billers but not regular users"

        it "grants access to owner of statement" do
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

      let!(:community) { create(:community) }
      let!(:other_community) { create(:community) }
      let!(:account1) { create(:account, community: community) }
      let!(:account2) { create(:account, community: community, household: user.household) }
      let!(:account3) { create(:account, community: other_community, household: user.household) }
      let!(:account4) { create(:account, community: other_community) }
      let!(:statement1) { create(:statement, account: account1) }
      let!(:statement2) { create(:statement, account: account2) }
      let!(:statement3) { create(:statement, account: account3) }
      let!(:statement4) { create(:statement, account: account4) }

      shared_examples_for "returns statements from community or household" do
        it "returns all statements from own community or household only" do
          permitted = StatementPolicy::Scope.new(user, Statement.all).resolve
          expect(permitted).to contain_exactly(statement1, statement2, statement3)
        end
      end

      context "admin" do
        let!(:user) { create(:admin) }
        it_behaves_like "returns statements from community or household"
      end

      context "biller" do
        let!(:user) { create(:biller) }
        it_behaves_like "returns statements from community or household"
      end

      context "regular user" do
        let!(:user) { create(:user) }

        it "returns all statements from own household only" do
          permitted = StatementPolicy::Scope.new(user, Statement.all).resolve
          expect(permitted).to contain_exactly(statement2, statement3)
        end
      end
    end
  end
end

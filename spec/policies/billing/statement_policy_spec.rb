require 'rails_helper'

module Billing
  describe StatementPolicy do
    describe "permissions" do
      include_context "policy objs"

      let(:statement) { Statement.new }
      let(:statement_owner) { User.new(household: Household.new) }

      before do
        allow(statement).to receive(:household).and_return(statement_owner.household)
        allow(statement).to receive(:community).and_return(community)
      end

      shared_examples_for :admins_and_billers do
        it "grants access to admins" do
          expect(subject).to permit(admin, Statement)
        end

        it "grants access to biller" do
          expect(subject).to permit(biller, Statement)
        end

        it "denies access to normal user" do
          expect(subject).not_to permit(user, Statement)
        end
      end

      shared_examples_for :admins_and_billers_with_community do
        it "grants access to admins from community" do
          expect(subject).to permit(admin, statement)
        end

        it "grants access to billers from community" do
          expect(subject).to permit(admin, statement)
        end

        it "denies access to admins from outside community" do
          expect(subject).not_to permit(outside_admin, statement)
        end

        it "denies access to billers from outside community" do
          expect(subject).not_to permit(outside_biller, statement)
        end

        it "denies access to regular user" do
          expect(subject).not_to permit(user, statement)
        end
      end

      permissions :index?, :generate? do
        it_behaves_like :admins_and_billers
      end

      permissions :show? do
        it_behaves_like :admins_and_billers_with_community

        it "grants access to owner of statement" do
          expect(subject).to permit(statement_owner, statement)
        end

        context "with inactive owner" do
          before { statement_owner.deactivated_at = Time.now }

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

      shared_examples_for :admin_or_biller do
        it "returns all statements from own community or household only" do
          permitted = StatementPolicy::Scope.new(user, Statement.all).resolve
          expect(permitted).to contain_exactly(statement1, statement2, statement3)
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

        it "returns all statements from own household only" do
          permitted = StatementPolicy::Scope.new(user, Statement.all).resolve
          expect(permitted).to contain_exactly(statement2, statement3)
        end
      end
    end
  end
end
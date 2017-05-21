require 'rails_helper'

describe Billing::StatementJob do
  include_context "jobs"

  describe "perform" do
    context "with accounts having activity" do
      # Accounts and households will be in default_community
      let!(:trans1) { create(:transaction) }
      let!(:trans2) { create(:transaction) }

      it "should send emails and create statements" do
        expect do
          perform_job(trans1.community_id)
        end.to change { ActionMailer::Base.deliveries.size }.by(2)
        expect(statement_count).to eq 2

        # Should do nothing the second time because of recent statement.
        expect do
          perform_job(trans1.community_id)
        end.to change { ActionMailer::Base.deliveries.size }.by(0)
        expect(statement_count).to eq 2
      end
    end

    context "with no accounts having activity" do
      it "should do nothing" do
        expect do
          perform_job(default_community.id)
        end.to change { ActionMailer::Base.deliveries.size }.by(0)
        expect(statement_count).to eq 0
      end
    end

    def statement_count
      ActsAsTenant.without_tenant { Billing::Statement.count }
    end
  end
end

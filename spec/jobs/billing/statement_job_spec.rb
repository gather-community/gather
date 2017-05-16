require 'rails_helper'

describe Billing::StatementJob do
  describe "perform" do
    context "with accounts having activity" do
      # Accounts and households will be in default_community
      let!(:trans1) { create(:transaction) }
      let!(:trans2) { create(:transaction) }

      it "should send emails and create statements" do
        expect do
          Billing::StatementJob.new(trans1.community_id).perform
        end.to change { ActionMailer::Base.deliveries.size }.by(2)
        expect(Billing::Statement.count).to eq 2

        # Should do nothing the second time because of recent statement.
        expect do
          Billing::StatementJob.new(trans1.community_id).perform
        end.to change { ActionMailer::Base.deliveries.size }.by(0)
        expect(Billing::Statement.count).to eq 2
      end
    end

    context "with no accounts having activity" do
      it "should do nothing" do
        expect do
          Billing::StatementJob.new(default_community.id).perform
        end.to change { ActionMailer::Base.deliveries.size }.by(0)
        expect(Billing::Statement.count).to eq 0
      end
    end
  end
end

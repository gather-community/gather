# frozen_string_literal: true

require "rails_helper"

describe Billing::StatementJob do
  include_context "jobs"

  describe "perform" do
    context "with accounts having activity" do
      # Accounts and households will be in Defaults.community
      let!(:trans1) { create(:transaction) }
      let!(:trans2) { create(:transaction) }
      subject(:job) { described_class.new(trans1.community_id) }

      it "should send emails and create statements" do
        expect(email_sent_by { perform_job }.size).to eq(2)
        expect(statement_count).to eq(2)

        # Should do nothing the second time because of recent statement.
        expect(email_sent_by { perform_job }.size).to eq(0)
        expect(statement_count).to eq(2)
      end
    end

    context "with no accounts having activity" do
      subject(:job) { described_class.new(Defaults.community.id) }

      it "should do nothing" do
        expect(email_sent_by { perform_job }.size).to eq(0)
        expect(statement_count).to eq(0)
      end
    end

    def statement_count
      ActsAsTenant.without_tenant { Billing::Statement.count }
    end
  end
end

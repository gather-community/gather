# frozen_string_literal: true

require "rails_helper"

describe Billing::AccountCsvExporter do
  let(:actor) { create(:biller) }
  let(:policy) do
    Billing::AccountPolicy.new(actor, Billing::Account.new(community: actor.community))
  end
  let(:exporter) { described_class.new(Billing::Account.active.by_cmty_and_household_name, policy: policy) }

  describe "to_csv" do
    context "with no accounts" do
      it "returns valid csv" do
        # Full headers are tested below.
        expect(exporter.to_csv).to match(/\ANumber,/)
      end
    end

    context "with accounts" do
      # Deliberately make first community come lexically second to test sort is respected.
      let!(:communities) { [create(:community, name: "Bravo"), create(:community, name: "Alpha")] }
      let!(:households) do
        Timecop.freeze("2018-09-22 9:00") do
          [
            create(:household, community: communities[0], name: "Smith"),
            create(:household, community: communities[1], name: "Li")
          ]
        end
      end
      let!(:accounts) { households.map { |h| h.accounts[0] } }

      before do
        create(:transaction, account: accounts[0], amount: 1.23, code: "othchg")
        create(:transaction, account: accounts[1], amount: 3.56, code: "othcrd")
        Timecop.freeze("2018-10-23 12:00") do
          Billing::Statement.new(account: accounts[0], prev_balance: 0).populate!
          Billing::Statement.new(account: accounts[1], prev_balance: 0).populate!
        end
        create(:transaction, account: accounts[0], amount: 6.78, code: "othcrd")
        create(:transaction, account: accounts[1], amount: 8.90, code: "othchg")
        accounts[1].update!(credit_limit: 50)
        accounts[0].recalculate!
        accounts[1].recalculate!
      end

      it "returns valid csv" do
        expect(exporter.to_csv)
          .to eq(prepare_fixture("billing/accounts.csv",
                                 number: accounts.map { |a| a.id.to_s.rjust(6, "0") },
                                 household_id: accounts.map(&:household_id),
                                 community_id: accounts.map(&:community_id),
                                 last_statement_id: accounts.map(&:last_statement_id)))
      end
    end
  end
end

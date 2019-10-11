# frozen_string_literal: true

require "rails_helper"

describe Billing::AccountExporter do
  let(:actor) { create(:biller) }
  let(:policy) do
    Billing::AccountPolicy.new(actor, Billing::Account.new(community: actor.community))
  end
  let(:exporter) { described_class.new(Billing::Account.all, policy: policy) }

  describe "to_csv" do
    context "with no accounts" do
      it "returns valid csv" do
        expect(exporter.to_csv).to eq("Number,Household ID,Household Name,Balance Due,Current Balance,"\
          "Credit Limit,Last Statement ID,Last Statement Date,Due Last Statement,Total New Charges,"\
          "Total New Credits,Creation Date\n")
      end
    end

    context "with accounts" do
      let!(:accounts) do
        Timecop.freeze("2018-09-23 10:00") do
          [create(:account), create(:account, credit_limit: 50)]
        end
      end

      before do
        create(:transaction, account: accounts[0], amount: 1.23, code: "othchg")
        create(:transaction, account: accounts[1], amount: 3.56, code: "othcrd")
        Timecop.freeze("2018-10-23 12:00") do
          Billing::Statement.new(account: accounts[0], prev_balance: 0).populate!
          Billing::Statement.new(account: accounts[1], prev_balance: 0).populate!
        end
        create(:transaction, account: accounts[0], amount: 6.78, code: "othcrd")
        create(:transaction, account: accounts[1], amount: 8.90, code: "othchg")
        accounts[0].recalculate!
        accounts[1].recalculate!
      end

      it "returns valid csv" do
        expect(exporter.to_csv).to eq(prepare_expectation("accounts.csv",
          number: accounts.map { |a| a.id.to_s.rjust(6, "0") },
          household_id: accounts.map(&:household_id),
          household_name: accounts.map(&:household_name),
          last_statement_id: accounts.map(&:last_statement_id)
        ))
      end
    end
  end
end

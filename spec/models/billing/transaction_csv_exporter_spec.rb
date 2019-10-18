# frozen_string_literal: true

require "rails_helper"

describe Billing::TransactionCsvExporter do
  let(:actor) { create(:biller) }
  let(:policy) do
    Billing::TransactionPolicy.new(actor, Billing::Transaction.new)
  end
  let(:exporter) { described_class.new(Billing::Transaction.oldest_first, policy: policy) }

  describe "to_csv" do
    context "with no transactions" do
      it "returns valid csv" do
        # Full headers are tested below.
        expect(exporter.to_csv).to match(/\A"ID",/)
      end
    end

    context "with transactions" do
      let(:account) { create(:account) }
      let(:meal) { create(:meal, served_at: "2018-08-17 18:15") }
      let!(:transactions) do
        Timecop.freeze("2018-09-10 12:00") do
          [
            create(:transaction, account: account, incurred_on: "2018-09-05", amount: -1.23, code: "othcrd",
                                 description: "Mistake correction"),
            create(:transaction, account: account, incurred_on: "2018-09-01", code: "meal",
                                 quantity: 3, unit_price: 1.50, statementable: meal,
                                 description: "Tasty burgers - Adult")
          ]
        end
      end
      let!(:statement) do
        Billing::Statement.new(account: account, prev_balance: 0).tap(&:populate!)
      end

      it "returns valid csv" do
        expect(exporter.to_csv).to eq(prepare_expectation("transactions.csv",
          id: transactions.map(&:id),
          account_id: [account.id],
          statement_id: [statement.id],
          meal_id: [meal.id]))
      end
    end
  end
end

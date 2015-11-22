require 'rails_helper'

RSpec.describe Statement, type: :model do
  let(:account){ create(:account) }

  describe "populate!" do
    it "should populate properly if previous statement" do
      prev_stmt = nil
      Timecop.freeze(Time.now - 7.days) do
        prev_stmt = create(:statement, account: account)
        create(:transaction, account: account, incurred_on: "2015-01-01",
          amount: 1.23, statement: prev_stmt)
      end
      txn2 = create(:transaction, account: account, incurred_on: "2015-01-02", amount: 2.34)
      txn3 = create(:transaction, account: account, incurred_on: "2015-01-03", amount: 3.45)
      txn4 = create(:transaction, account: account, incurred_on: "2015-01-06", amount: 4.56)
      decoy = create(:transaction, incurred_on: "2015-01-06", amount: 5.67)

      statement = Statement.new(account: account, prev_balance: -0.12)
      expect(statement.populate!).to be true
      statement.reload
      expect(statement.transactions.sort_by(&:id)).to eq [txn2, txn3, txn4]
      expect(statement.total_due).to eq 10.23
      expect(statement.prev_stmt_on).to eq Date.today - 7.days
    end

    it "should populate properly if no previous statement" do
      create(:transaction, account: account, incurred_on: "2015-01-02", amount: 2.34)
      statement = Statement.new(account: account, prev_balance: 4.00)
      expect(statement.populate!).to be true
      statement.reload
      expect(statement.total_due).to eq 6.34
      expect(statement.prev_stmt_on).to be_nil
    end

    it "should not raise if there are no relevant transactions but balance is nonzero" do
      txn1 = create(:transaction, account: account, incurred_on: "2015-01-01",
        amount: 1.23, statement: create(:statement))
      statement = Statement.new(account: account, prev_balance: -0.12)
      statement.populate!
    end

    it "should raise if there are no relevant transactions and balance is zero" do
      txn1 = create(:transaction, account: account, incurred_on: "2015-01-01",
        amount: 1.23, statement: create(:statement))
      statement = Statement.new(account: account, prev_balance: 0)
      expect{statement.populate!}.to raise_error(StatementError)
    end
  end
end

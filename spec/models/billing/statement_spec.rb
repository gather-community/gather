# frozen_string_literal: true

require "rails_helper"

describe Billing::Statement do
  let(:account) { create(:account) }

  describe "populate!" do
    it "should populate properly if previous statement" do
      prev_stmt = nil
      Timecop.freeze(Time.current - 7.days) do
        prev_stmt = create(:statement, account: account)
        create(:transaction, account: account, incurred_on: "2015-01-01",
                             value: 1.23, statement: prev_stmt)
      end
      txn2 = create(:transaction, account: account, incurred_on: "2015-01-02", value: 2.34)
      txn3 = create(:transaction, account: account, incurred_on: "2015-01-03", value: 3.45)
      txn4 = create(:transaction, account: account, incurred_on: "2015-01-06", value: 4.56)
      create(:transaction, incurred_on: "2015-01-06", value: 5.67) # Decoy

      statement = described_class.new(account: account, prev_balance: -0.12)
      expect(statement.populate!).to be(true)
      statement.reload
      expect(statement.transactions.sort_by(&:id)).to eq([txn2, txn3, txn4])
      expect(statement.total_due).to eq(10.23)
      expect(statement.prev_stmt_on).to eq((Time.current - 7.days).to_date)
    end

    it "should populate properly if no previous statement" do
      create(:transaction, account: account, incurred_on: "2015-01-02", value: 2.34)
      statement = described_class.new(account: account, prev_balance: 4.00)
      expect(statement.populate!).to be(true)
      statement.reload
      expect(statement.total_due).to eq(6.34)
      expect(statement.prev_stmt_on).to be_nil
    end

    it "should not raise if there are no relevant transactions but balance is nonzero" do
      create(:transaction, account: account, incurred_on: "2015-01-01",
                           value: 1.23, statement: create(:statement))
      statement = described_class.new(account: account, prev_balance: -0.12)
      statement.populate!
    end

    it "should raise if there are no relevant transactions and balance is zero" do
      create(:transaction, account: account, incurred_on: "2015-01-01",
                           value: 1.23, statement: create(:statement))
      statement = described_class.new(account: account, prev_balance: 0)
      expect { statement.populate! }.to raise_error(Billing::StatementError)
    end
  end

  describe "due_within_days_from_now" do
    let!(:s1) { create(:statement, due_on: Time.zone.today + 29.days) }
    let!(:s2) { create(:statement, due_on: Time.zone.today + 31.days) }
    let!(:s3) { create(:statement, due_on: Time.zone.today + 33.days) }
    let!(:s4) { create(:statement, due_on: nil) } # nil due date should not be included

    it "should return the correct statements" do
      expect(described_class.due_within_days_from_now(31).to_a).to contain_exactly(s1, s2)
    end
  end
end

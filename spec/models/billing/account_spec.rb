# frozen_string_literal: true

# == Schema Information
#
# Table name: accounts
#
#  id                 :integer          not null, primary key
#  balance_due        :decimal(10, 2)   default(0.0), not null
#  cluster_id         :integer          not null
#  community_id       :integer          not null
#  created_at         :datetime         not null
#  credit_limit       :decimal(10, 2)
#  current_balance    :decimal(10, 2)   default(0.0), not null
#  due_last_statement :decimal(10, 2)
#  household_id       :integer          not null
#  last_statement_id  :integer
#  last_statement_on  :date
#  total_new_charges  :decimal(10, 2)   default(0.0), not null
#  total_new_credits  :decimal(10, 2)   default(0.0), not null
#  updated_at         :datetime         not null
#
require "rails_helper"

describe Billing::Account do
  let(:account) { create(:account, total_new_credits: 4, total_new_charges: 7) }
  let(:statement) { create(:statement, account: account) }

  describe "transaction_added" do
    it "should work for new charge" do
      create(:transaction, code: "othchg", account: account, value: 6)
      expect(account.reload.total_new_credits).to eq(4)
      expect(account.total_new_charges).to eq(13)
      expect(account.balance_due).to eq(4.81)
      expect(account.current_balance).to eq(17.81)
    end

    it "should work for new credit" do
      create(:transaction, code: "othcrd", account: account, value: 6)
      expect(account.reload.total_new_credits).to eq(10)
      expect(account.total_new_charges).to eq(7)
      expect(account.balance_due).to eq(-1.19)
      expect(account.current_balance).to eq(5.81)
    end
  end

  describe "statement_added" do
    it "should update fields" do
      statement
      expect(account.last_statement_on).to eq(statement.created_on)
      expect(account.due_last_statement).to eq(statement.total_due)
      expect(account.last_statement).to eq(statement)
      expect(account.total_new_credits).to eq(0)
      expect(account.total_new_charges).to eq(0)
      expect(account.balance_due).to eq(9.99)
      expect(account.current_balance).to eq(9.99)
    end
  end

  describe "recalculate!" do
    it "should work with existing statements and line items" do
      Timecop.travel(Time.zone.today - 30.days) do
        @inv1 = create(:statement, account: account, total_due: 10)
      end
      @inv2 = create(:statement, account: account, total_due: 15)
      create(:transaction, code: "othchg", account: account, value: 5, statement: @inv2)
      create(:transaction, code: "othcrd", account: account, value: 8, statement: @inv2)
      create(:transaction, code: "othchg", account: account,
                           quantity: 2, unit_price: 2.25, statement: @inv2)
      create(:transaction, code: "othcrd", account: account, value: 2.35, statement: @inv2)
      @inv2.destroy
      expect(account.last_statement_on).to eq(@inv1.created_on)
      expect(account.due_last_statement).to eq(10)
      expect(account.last_statement).to eq(@inv1)
      expect(account.total_new_credits).to eq(10.35)
      expect(account.total_new_charges).to eq(9.5)
      expect(account.balance_due).to eq(-0.35)
      expect(account.current_balance).to eq(9.15)
    end

    it "should work with no line items or statements" do
      account.recalculate!
      expect(account.last_statement_on).to be_nil
      expect(account.due_last_statement).to be_nil
      expect(account.last_statement).to be_nil
      expect(account.total_new_credits).to eq(0)
      expect(account.total_new_charges).to eq(0)
      expect(account.balance_due).to eq(0)
      expect(account.current_balance).to eq(0)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Billing::TransactionDecorator do
  let(:transaction) { described_class.new(Billing::Transaction.new) }

  describe "#transaction_code_options" do
    it "lists the charges that can be added by hand" do
      expect(transaction.transaction_code_options(:increase)).to eq([
        ["Meal charge", "meal"],
        ["Membership dues charge", "dues"],
        ["Payout to user", "payout"],
        ["Other charge", "othchg"]
      ])
    end

    it "lists the credits that can be added by hand" do
      expect(transaction.transaction_code_options(:decrease)).to eq([
        ["Payment to community", "payment"],
        ["Meal reimbursement credit", "reimb"],
        ["Other credit", "othcrd"]
      ])
    end
  end
end

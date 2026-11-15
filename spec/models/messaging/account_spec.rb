# frozen_string_literal: true

require "rails_helper"

describe Messaging::Account do
  describe "#balance" do
    let(:account) { create(:messaging_account, currency: "usd") }

    it "sums transaction amounts and wraps them as Money" do
      create(:messaging_transaction, account: account, amount_cents: 1000)
      create(:messaging_transaction, account: account, amount_cents: 500)
      expect(account.balance_cents).to eq(1500)
      expect(account.balance).to eq(Money.new(1500, "usd"))
    end

    it "is zero with no transactions" do
      expect(account.balance_cents).to eq(0)
    end
  end

  it "requires a currency" do
    account = build(:messaging_account, currency: nil)
    expect(account).not_to be_valid
    expect(account.errors[:currency]).to be_present
  end
end

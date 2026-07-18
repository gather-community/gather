# frozen_string_literal: true

require "rails_helper"

describe Subscription::MessagingTopup do
  describe ".options_for" do
    it "maps usd to the 2/5/10/20 dollar tiers in cents" do
      expect(described_class.options_for("usd")).to eq(
        [
          {cents: 200, label: "$2.00"},
          {cents: 500, label: "$5.00"},
          {cents: 1000, label: "$10.00"},
          {cents: 2000, label: "$20.00"}
        ]
      )
    end

    it "handles zero-decimal currencies (jpy) without multiplying by 100" do
      expect(described_class.options_for("jpy").pluck(:cents)).to eq([300, 750, 1500, 3000])
    end

    it "returns [] for an unmapped currency (topup UI is then hidden)" do
      expect(described_class.options_for("xyz")).to eq([])
    end

    it "covers every currency in Community::COUNTRY_CURRENCIES" do
      missing = Community::COUNTRY_CURRENCIES.values.uniq - described_class::AMOUNTS_BY_CURRENCY.keys
      expect(missing).to be_empty
    end
  end

  describe "live Stripe helpers" do
    let(:topup) { build(:messaging_topup) }

    it "reads amount, currency and status from the populated Stripe subscription" do
      topup.stripe_sub = double(
        status: "active", cancel_at_period_end: false, current_period_end: Time.zone.local(2026, 8, 1).to_i,
        items: double(data: [double(price: double(unit_amount: 500, currency: "usd"))]),
        latest_invoice: nil
      )
      expect(topup.amount_cents).to eq(500)
      expect(topup.currency).to eq("usd")
      expect(topup.active?).to be(true)
      expect(topup.canceling?).to be(false)
      expect(topup.next_bill_date).to eq(Date.new(2026, 8, 1))
    end
  end
end

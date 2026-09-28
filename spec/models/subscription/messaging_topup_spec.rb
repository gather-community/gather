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
      item = stripe_subscription_item_double(
        current_period_end: Time.zone.local(2026, 8, 1).to_i,
        price: double(unit_amount: 500, currency: "usd")
      )
      topup.stripe_sub = stripe_subscription_double(
        status: "active", cancel_at_period_end: false, items: [item], latest_invoice: nil
      )
      expect(topup.amount_cents).to eq(500)
      expect(topup.currency).to eq("usd")
      expect(topup.active?).to be(true)
      expect(topup.canceling?).to be(false)
      expect(topup.next_bill_date).to eq(Date.new(2026, 8, 1))
    end
  end

  describe "#reap_if_canceled!" do
    let!(:topup) { create(:messaging_topup, community: Defaults.community) }

    # Once Stripe actually cancels, cancel_at_period_end flips back to false and the item and price
    # stay readable, so nothing about the payload marks the topup as dead except the status.
    def stub_stripe(status:, cancel_at_period_end: false)
      item = stripe_subscription_item_double(
        current_period_end: Time.zone.local(2026, 8, 1).to_i,
        price: double(unit_amount: 1000, currency: "usd")
      )
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        stripe_subscription_double(status: status, cancel_at_period_end: cancel_at_period_end,
          items: [item], latest_invoice: nil)
      )
    end

    it "destroys the row and returns true once Stripe has canceled" do
      stub_stripe(status: "canceled")
      expect(topup.reap_if_canceled!).to be(true)
      expect(described_class.count).to eq(0)
    end

    it "keeps a topup that is merely winding down" do
      stub_stripe(status: "active", cancel_at_period_end: true)
      expect(topup.reap_if_canceled!).to be(false)
      expect(described_class.count).to eq(1)
    end

    it "keeps a cleanly active topup" do
      stub_stripe(status: "active")
      expect(topup.reap_if_canceled!).to be(false)
      expect(described_class.count).to eq(1)
    end

    it "keeps a past_due topup, which is still alive" do
      stub_stripe(status: "past_due")
      expect(topup.reap_if_canceled!).to be(false)
      expect(described_class.count).to eq(1)
    end

    # The credits were paid for and messaging works until they are spent.
    it "leaves the wallet balance untouched" do
      account = create(:messaging_account, community: Defaults.community)
      create(:messaging_transaction, account: account, amount_cents: 1496)
      stub_stripe(status: "canceled")
      topup.reap_if_canceled!
      expect(account.reload.balance_cents).to eq(1496)
    end

    it "reuses an already-populated stripe_sub rather than re-fetching" do
      topup.stripe_sub = stripe_subscription_double(status: "canceled", cancel_at_period_end: false,
        items: [stripe_subscription_item_double], latest_invoice: nil)
      expect(Stripe::Subscription).not_to receive(:retrieve)
      expect(topup.reap_if_canceled!).to be(true)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Subscription::MessagingTopupManager do
  let(:community) { Defaults.community } # country_code US => usd
  let(:customer) do
    double(id: "cus_1", invoice_settings: double(default_payment_method: nil))
  end
  let(:subscription) do
    build(:subscription, community: community).tap do |s|
      # The base subscription saves the card on the subscription itself, not on the customer.
      s.stripe_sub = double(customer: customer, default_payment_method: "pm_1")
    end
  end
  subject(:manager) { described_class.new(community: community, subscription: subscription) }

  let(:price) { double(id: "price_1", unit_amount: 500, currency: "usd") }

  describe "#set_amount!" do
    before do
      allow(Stripe::Price).to receive(:list).and_return(double(data: []))
      allow(Stripe::Price).to receive(:create).and_return(price)
    end

    context "when no topup subscription exists yet" do
      it "creates a monthly subscription billed now and persists the local record" do
        expect(Stripe::Subscription).to receive(:create).with(
          hash_including(customer: "cus_1", default_payment_method: "pm_1")
        ).and_return(double(id: "sub_topup_new"))

        expect { manager.set_amount!(500) }.to change(Subscription::MessagingTopup, :count).by(1)
        expect(community.reload.messaging_topup.stripe_id).to eq("sub_topup_new")
      end

      it "creates a monthly ($/mo) price under the messaging product" do
        allow(Stripe::Subscription).to receive(:create).and_return(double(id: "sub_topup_new"))
        expect(Stripe::Price).to receive(:create).with(
          hash_including(unit_amount: 500, currency: "usd",
            recurring: {interval: "month", interval_count: 1})
        ).and_return(price)
        manager.set_amount!(500)
      end
    end

    context "when a topup subscription already exists" do
      let!(:topup) { create(:messaging_topup, community: community, stripe_id: "sub_topup_x") }

      before do
        allow(Stripe::Subscription).to receive(:retrieve).and_return(
          double(items: double(data: [double(id: "si_1")]))
        )
      end

      it "swaps the item price and invoices the proration immediately" do
        expect(Stripe::SubscriptionItem).to receive(:update).with(
          "si_1", hash_including(price: "price_1", proration_behavior: "always_invoice")
        )
        manager.set_amount!(500)
      end
    end
  end

  describe "#cancel!" do
    it "schedules cancellation at period end" do
      create(:messaging_topup, community: community, stripe_id: "sub_topup_x")
      expect(Stripe::Subscription).to receive(:update).with("sub_topup_x", cancel_at_period_end: true)
      manager.cancel!
    end

    it "is a no-op when there is no topup" do
      expect(Stripe::Subscription).not_to receive(:update)
      manager.cancel!
    end
  end

  describe "#preview" do
    let!(:topup) { create(:messaging_topup, community: community, stripe_id: "sub_topup_x") }

    before do
      allow(Stripe::Price).to receive(:list).and_return(double(data: []))
      allow(Stripe::Price).to receive(:create).and_return(price)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        double(items: double(data: [double(id: "si_1")]),
          current_period_end: Time.zone.local(2026, 8, 1).to_i)
      )
    end

    it "sums the proration lines of the previewed invoice" do
      allow(Stripe::Invoice).to receive(:upcoming).and_return(
        double(lines: double(data: [
          double(proration: true, amount: 250),
          double(proration: false, amount: 500)
        ]))
      )
      expect(manager.preview(500)[:immediate_charge_cents]).to eq(250)
    end

    it "returns nil when there is no existing topup (first activation has no proration)" do
      topup.destroy
      community.reload # clear the cached messaging_topup association
      manager = described_class.new(community: community, subscription: subscription)
      expect(manager.preview(500)).to be_nil
    end
  end
end

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
          hash_including(customer: "cus_1", default_payment_method: "pm_1",
            payment_behavior: "error_if_incomplete")
        ).and_return(double(id: "sub_topup_new", latest_invoice: double("invoice", id: "in_x")))

        expect { manager.set_amount!(500) }.to change(Subscription::MessagingTopup, :count).by(1)
        expect(community.reload.messaging_topup.stripe_id).to eq("sub_topup_new")
      end

      it "returns the finalized invoice for synchronous crediting" do
        invoice = double("invoice", id: "in_x")
        allow(Stripe::Subscription).to receive(:create)
          .and_return(double(id: "sub_topup_new", latest_invoice: invoice))
        expect(manager.set_amount!(500)).to eq(invoice)
      end

      it "creates a monthly ($/mo) price under the messaging product" do
        allow(Stripe::Subscription).to receive(:create)
          .and_return(double(id: "sub_topup_new", latest_invoice: double("invoice", id: "in_x")))
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
          double(status: "active", cancel_at_period_end: false,
            items: double(data: [double(id: "si_1")]), latest_invoice: double("invoice", id: "in_x"))
        )
      end

      it "swaps the item price and invoices the proration immediately" do
        expect(Stripe::SubscriptionItem).to receive(:update).with(
          "si_1", hash_including(price: "price_1", proration_behavior: "always_invoice")
        )
        manager.set_amount!(500)
      end

      it "does not touch cancel_at_period_end when nothing is scheduled" do
        allow(Stripe::SubscriptionItem).to receive(:update)
        expect(Stripe::Subscription).not_to receive(:update)
        manager.set_amount!(500)
      end
    end

    # Re-adding a topup during its wind-down must genuinely revive it. The Stripe item still exists
    # while cancelling, so without clearing cancel_at_period_end the price swap lands on a
    # subscription that is still ending and the user wrongly believes they re-subscribed.
    context "when the existing topup is winding down" do
      let!(:topup) { create(:messaging_topup, community: community, stripe_id: "sub_topup_x") }

      before do
        allow(Stripe::Subscription).to receive(:retrieve).and_return(
          double(status: "active", cancel_at_period_end: true,
            items: double(data: [double(id: "si_1")]), latest_invoice: double("invoice", id: "in_x"))
        )
        allow(Stripe::SubscriptionItem).to receive(:update)
      end

      it "clears cancel_at_period_end so the topup is genuinely revived" do
        expect(Stripe::Subscription).to receive(:update)
          .with("sub_topup_x", cancel_at_period_end: false)
        manager.set_amount!(500)
      end

      # Reviving before the swap means a failure clearing the cancellation leaves the topup untouched
      # rather than repriced but still dying.
      it "revives before repricing" do
        calls = []
        allow(Stripe::Subscription).to receive(:update) { calls << :resume }
        allow(Stripe::SubscriptionItem).to receive(:update) { calls << :reprice }
        manager.set_amount!(500)
        expect(calls).to eq([:resume, :reprice])
      end

      it "revives and reprices when the community picks a different amount" do
        expect(Stripe::Subscription).to receive(:update)
          .with("sub_topup_x", cancel_at_period_end: false)
        expect(Stripe::SubscriptionItem).to receive(:update).with(
          "si_1", hash_including(price: "price_1", proration_behavior: "always_invoice")
        )
        manager.set_amount!(2000)
      end

      it "keeps the local record rather than creating a second one" do
        expect { manager.set_amount!(500) }.not_to change(Subscription::MessagingTopup, :count)
        expect(community.reload.messaging_topup.stripe_id).to eq("sub_topup_x")
      end
    end

    # Once Stripe has actually canceled, the item and price are still readable, so repricing would
    # target a dead subscription. The stale row is reaped and a fresh subscription created instead.
    context "when the existing topup's Stripe subscription has already ended" do
      let!(:topup) { create(:messaging_topup, community: community, stripe_id: "sub_topup_dead") }

      before do
        allow(Stripe::Subscription).to receive(:retrieve).and_return(
          double(status: "canceled", cancel_at_period_end: false,
            items: double(data: [double(id: "si_1")]), latest_invoice: nil)
        )
      end

      it "reaps the stale row and creates a fresh subscription" do
        expect(Stripe::SubscriptionItem).not_to receive(:update)
        expect(Stripe::Subscription).to receive(:create)
          .and_return(double(id: "sub_topup_new", latest_invoice: double("invoice", id: "in_x")))

        manager.set_amount!(500)

        expect(community.reload.messaging_topup.stripe_id).to eq("sub_topup_new")
        expect(Subscription::MessagingTopup.where(stripe_id: "sub_topup_dead")).to be_empty
      end
    end
  end

  describe "#cancel!" do
    it "schedules cancellation at period end" do
      create(:messaging_topup, community: community, stripe_id: "sub_topup_x")
      allow(Stripe::Subscription).to receive(:retrieve)
        .and_return(stripe_subscription_double(status: "active", cancel_at_period_end: false))
      expect(Stripe::Subscription).to receive(:update).with("sub_topup_x", cancel_at_period_end: true)
      manager.cancel!
    end

    it "is a no-op when there is no topup" do
      expect(Stripe::Subscription).not_to receive(:update)
      manager.cancel!
    end

    it "reaps the local row instead of cancelling a subscription Stripe has already ended" do
      create(:messaging_topup, community: community, stripe_id: "sub_topup_dead")
      allow(Stripe::Subscription).to receive(:retrieve)
        .and_return(stripe_subscription_double(status: "canceled", cancel_at_period_end: false))
      expect(Stripe::Subscription).not_to receive(:update)
      expect { manager.cancel! }.to change(Subscription::MessagingTopup, :count).by(-1)
    end
  end

  describe "#preview" do
    let!(:topup) { create(:messaging_topup, community: community, stripe_id: "sub_topup_x") }

    before do
      allow(Stripe::Price).to receive(:list).and_return(double(data: []))
      allow(Stripe::Price).to receive(:create).and_return(price)
      item = stripe_subscription_item_double(id: "si_1",
        current_period_end: Time.zone.local(2026, 8, 1).to_i)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        stripe_subscription_double(status: "active", cancel_at_period_end: false, items: [item])
      )
    end

    it "sums the proration lines of the previewed invoice" do
      allow(Stripe::Invoice).to receive(:create_preview).and_return(
        stripe_invoice_double(lines: [
          stripe_invoice_line_double(proration: true, amount: 250),
          stripe_invoice_line_double(proration: false, amount: 500)
        ])
      )
      expect(manager.preview(500)[:immediate_charge_cents]).to eq(250)
    end

    it "passes the item swap under subscription_details, as Basil requires" do
      expect(Stripe::Invoice).to receive(:create_preview).with(
        hash_including(subscription: "sub_topup_x",
          subscription_details: {items: [{id: "si_1", price: "price_1"}],
                                 proration_behavior: "create_prorations"})
      ).and_return(stripe_invoice_double(lines: []))
      manager.preview(500)
    end

    it "returns nil when there is no existing topup (first activation has no proration)" do
      topup.destroy
      community.reload # clear the cached messaging_topup association
      manager = described_class.new(community: community, subscription: subscription)
      expect(manager.preview(500)).to be_nil
    end
  end
end

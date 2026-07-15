# frozen_string_literal: true

require "rails_helper"

describe "Stripe webhooks" do
  let(:community) { Defaults.community } # country_code "US" => currency "usd"
  let(:stripe_sub_id) { "sub_test123" }
  let!(:subscription) { create(:subscription, community: community, stripe_id: stripe_sub_id) }
  let(:topup_sub_id) { "sub_topup123" }
  let!(:topup) { create(:messaging_topup, community: community, stripe_id: topup_sub_id) }
  let(:product_id) { Settings.stripe.messaging.topup_product_id }
  let(:secret) { Settings.stripe.webhook_signing_secret }

  before { use_apex_domain }

  # invoice.finalized reads the PaymentIntent's status to tell delayed/in-flight from unpaid.
  def stub_pi(status)
    allow(Stripe::PaymentIntent).to receive(:retrieve).with("pi_test").and_return(double(status: status))
  end

  describe "crediting from the payment lifecycle" do
    context "invoice.finalized with an in-flight (ACH) payment" do
      before { stub_pi("processing") }

      it "credits the wallet immediately and records the event id" do
        post_event(invoice_event("invoice.finalized", line_amount: 1500))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          account = Messaging::Account.first
          expect(account.community).to eq(community)
          expect(account.balance_cents).to eq(1500)
          txn = account.transactions.first
          expect(txn.amount_cents).to eq(1500)
          expect(txn.stripe_event_id).to eq("evt_test")
          expect(txn.stripe_invoice_line_item_id).to eq("il_test1")
        end
      end
    end

    context "invoice.finalized with a not-yet-paid card (declined/3DS)" do
      before { stub_pi("requires_payment_method") }

      it "does not credit" do
        post_event(invoice_event("invoice.finalized", line_amount: 1500))
        with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
      end
    end

    it "credits on invoice.paid" do
      post_event(invoice_event("invoice.paid", line_amount: 1500))
      with_default_tenant { expect(Messaging::Account.first.balance_cents).to eq(1500) }
    end

    it "credits the actual invoiced (prorated) amount, not the price's unit amount" do
      post_event(invoice_event("invoice.paid", line_amount: 300, unit_amount: 1500))
      with_default_tenant { expect(Messaging::Transaction.first.amount_cents).to eq(300) }
    end

    it "is idempotent across redelivery (no double credit)" do
      2.times { post_event(invoice_event("invoice.paid", line_amount: 1500)) }
      with_default_tenant do
        expect(Messaging::Transaction.count).to eq(1)
        expect(Messaging::Account.first.balance_cents).to eq(1500)
      end
    end

    context "with no messaging topup line" do
      it "ignores the event" do
        post_event(invoice_event("invoice.paid", product: "prod_other"))
        with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
      end
    end

    context "when the topup subscription is unknown in our DB" do
      it "ignores the event gracefully" do
        post_event(invoice_event("invoice.paid", subscription: "sub_unknown"))
        with_default_tenant { expect(Messaging::Account.count).to eq(0) }
      end
    end

    context "when the line currency does not match the account currency" do
      it "gives up without crediting" do
        post_event(invoice_event("invoice.paid", line_currency: "cad"))
        with_default_tenant { expect(Messaging::Account.count).to eq(0) }
      end
    end
  end

  describe "claw back" do
    before { post_event(invoice_event("invoice.paid", line_amount: 1500)) } # credit $15 first

    %w[invoice.payment_failed invoice.voided invoice.marked_uncollectible].each do |type|
      it "claws the credit back on #{type}" do
        post_event(invoice_event(type, line_amount: 1500))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          account = Messaging::Account.first
          expect(account.balance_cents).to eq(0)
          expect(account.transactions.count).to eq(2) # credit + offsetting claw-back
          expect(account.transactions.order(:id).last.amount_cents).to eq(-1500)
        end
      end
    end

    it "is idempotent across repeated failures" do
      2.times { post_event(invoice_event("invoice.payment_failed", line_amount: 1500)) }
      with_default_tenant do
        expect(Messaging::Account.first.balance_cents).to eq(0)
        expect(Messaging::Transaction.count).to eq(2) # one credit + one claw-back
      end
    end

    it "does nothing when there was no credit to claw back" do
      with_default_tenant { Messaging::Transaction.delete_all }
      post_event(invoice_event("invoice.voided", line_amount: 1500))
      with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
    end
  end

  describe "flip-flop across a retry" do
    it "re-credits when a retry succeeds after a failure" do
      post_event(invoice_event("invoice.paid", line_amount: 1500))           # +1500
      post_event(invoice_event("invoice.payment_failed", line_amount: 1500)) # -1500 (net 0)
      post_event(invoice_event("invoice.paid", line_amount: 1500))           # +1500 (net 1500)

      with_default_tenant do
        expect(Messaging::Account.first.balance_cents).to eq(1500)
        expect(Messaging::Transaction.count).to eq(3)
      end
    end
  end

  describe "logging" do
    it "emits a webhook_arrived event line resolving the community" do
      allow(Subscription::EventLog).to receive(:emit).and_call_original
      post_event(invoice_event("invoice.paid", line_amount: 1500))

      expect(Subscription::EventLog).to have_received(:emit).with(
        hash_including(event_name: "webhook_arrived", community_id: community.id,
          webhook_type: "invoice.paid", webhook_id: "evt_test")
      )
    end
  end

  describe "subscription cache sync" do
    it "enqueues a sync on customer.subscription.updated" do
      expect { post_event(subscription_updated_event) }
        .to have_enqueued_job(Subscription::SyncJob).with(subscription.id)
      expect(response).to have_http_status(:ok)
    end

    it "enqueues a sync on invoice.paid" do
      expect { post_event(invoice_event("invoice.paid", subscription: stripe_sub_id)) }
        .to have_enqueued_job(Subscription::SyncJob).with(subscription.id)
    end

    it "does not enqueue a sync for an unknown subscription" do
      expect { post_event(subscription_updated_event(id: "sub_unknown")) }
        .not_to have_enqueued_job(Subscription::SyncJob)
    end
  end

  context "with an invalid signature" do
    it "returns 400 and creates nothing" do
      payload = JSON.generate(invoice_event("invoice.paid"))
      post("/stripe/webhooks", params: payload,
        headers: {"Content-Type" => "application/json", "Stripe-Signature" => "t=123,v1=bogus"})

      expect(response).to have_http_status(:bad_request)
      expect(Stripe::WebhookEvent.count).to eq(0)
      with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
    end
  end

  # Minimal invoice event payload (stripe ~> 8.1 shape). unit_amount defaults to line_amount (they
  # differ only for proration lines). payment_intent is an id the finalize path retrieves.
  def invoice_event(type, subscription: topup_sub_id, product: product_id, line_amount: 1000,
    unit_amount: nil, line_currency: "usd")
    {
      id: "evt_test", object: "event", type: type,
      data: {object: {
        id: "in_test", object: "invoice", subscription: subscription, currency: line_currency,
        payment_intent: "pi_test",
        lines: {object: "list", data: [invoice_line(product, line_amount, unit_amount || line_amount,
          line_currency)]}
      }}
    }
  end

  def subscription_updated_event(id: stripe_sub_id)
    {
      id: "evt_test", object: "event", type: "customer.subscription.updated",
      data: {object: {id: id, object: "subscription", status: "active"}}
    }
  end

  def invoice_line(product, amount, unit_amount, currency)
    {
      id: "il_test1", object: "line_item", amount: amount, currency: currency,
      price: {id: "price_test", object: "price", product: product, unit_amount: unit_amount,
              currency: currency}
    }
  end

  def post_event(event)
    payload = JSON.generate(event)
    post("/stripe/webhooks", params: payload,
      headers: {"Content-Type" => "application/json"}.merge(signature_header(payload)))
  end

  def signature_header(payload, timestamp: Time.now.to_i)
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    {"Stripe-Signature" => "t=#{timestamp},v1=#{signature}"}
  end
end

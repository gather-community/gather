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

    it "credits the actual invoiced (prorated) line amount" do
      post_event(invoice_event("invoice.paid", line_amount: 300))
      with_default_tenant { expect(Messaging::Transaction.first.amount_cents).to eq(300) }
    end

    # Stripe does not expand `payments` on webhook deliveries, so this is the production path.
    it "resolves the PaymentIntent by listing payments when the payload omits them" do
      expect(Stripe::InvoicePayment).to receive(:list).with(invoice: "in_test")
        .and_return(double(data: [double(is_default: true,
          payment: double(payment_intent: "pi_test"))]))
      stub_pi("processing")

      post_event(invoice_event("invoice.finalized", line_amount: 1500, payments: false))

      with_default_tenant { expect(Messaging::Account.first.balance_cents).to eq(1500) }
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

  # A canceled topup subscription reads back from Stripe as a healthy active topup —
  # cancel_at_period_end flips to false and the item and price stay readable — so the local row must
  # go when the cancellation completes or the page shows a dead topup as live indefinitely.
  describe "a topup subscription reaching its scheduled end" do
    it "clears the local topup record" do
      post_event(subscription_deleted_event(id: topup_sub_id))

      expect(response).to have_http_status(:ok)
      with_default_tenant { expect(Subscription::MessagingTopup.count).to eq(0) }
    end

    # Those credits were paid for and messaging works until they are spent.
    it "leaves the wallet balance untouched" do
      account = create(:messaging_account, community: community)
      create(:messaging_transaction, account: account, amount_cents: 1496)

      post_event(subscription_deleted_event(id: topup_sub_id))

      with_default_tenant { expect(account.reload.balance_cents).to eq(1496) }
    end

    it "leaves the base subscription alone and still syncs it" do
      expect { post_event(subscription_deleted_event(id: stripe_sub_id)) }
        .to have_enqueued_job(Subscription::SyncJob).with(subscription.id)
      with_default_tenant do
        expect(Subscription::Subscription.count).to eq(1)
        expect(Subscription::MessagingTopup.count).to eq(1)
      end
    end

    it "ignores a subscription unknown to us" do
      post_event(subscription_deleted_event(id: "sub_unknown"))

      expect(response).to have_http_status(:ok)
      with_default_tenant { expect(Subscription::MessagingTopup.count).to eq(1) }
    end

    # Only the deleted event means the subscription has ended. An update while winding down must not
    # reap the row: the topup is still live and still owed the month already paid for.
    it "does not reap on customer.subscription.updated" do
      post_event(subscription_updated_event(id: topup_sub_id))
      with_default_tenant { expect(Subscription::MessagingTopup.count).to eq(1) }
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

  # Minimal invoice event payload in the Basil (2025-03-31) shape: the subscription moved under
  # `parent` and the PaymentIntent under `payments`. Pass payments: false to model a real webhook
  # delivery, which does not expand `payments` — InvoiceFields then lists them instead.
  def invoice_event(type, subscription: topup_sub_id, product: product_id, line_amount: 1000,
    line_currency: "usd", payments: true)
    invoice = {
      id: "in_test", object: "invoice", currency: line_currency,
      parent: {type: "subscription_details", subscription_details: {subscription: subscription}},
      lines: {object: "list", data: [invoice_line(product, line_amount, line_currency)]}
    }
    invoice[:payments] = {object: "list", data: [invoice_payment]} if payments
    {id: "evt_test", object: "event", type: type, data: {object: invoice}}
  end

  # An invoice's payment record. `payment.payment_intent` is an id the processor resolves.
  def invoice_payment
    {
      id: "inpay_test", object: "invoice_payment", is_default: true, status: "paid",
      invoice: "in_test", payment: {type: "payment_intent", payment_intent: "pi_test"}
    }
  end

  def subscription_updated_event(id: stripe_sub_id)
    {
      id: "evt_test", object: "event", type: "customer.subscription.updated",
      data: {object: {id: id, object: "subscription", status: "active"}}
    }
  end

  # Stripe clears cancel_at_period_end when it actually cancels, which is why the event type rather
  # than the payload is what tells us the subscription has ended.
  def subscription_deleted_event(id: stripe_sub_id)
    {
      id: "evt_test", object: "event", type: "customer.subscription.deleted",
      data: {object: {id: id, object: "subscription", status: "canceled",
                      cancel_at_period_end: false}}
    }
  end

  # Basil replaced the line's embedded `price` object with `pricing.price_details`, which carries
  # only the price and product ids — the unit amount is no longer on the line at all.
  def invoice_line(product, amount, currency)
    {
      id: "il_test1", object: "line_item", amount: amount, currency: currency,
      pricing: {type: "price_details", price_details: {price: "price_test", product: product}}
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

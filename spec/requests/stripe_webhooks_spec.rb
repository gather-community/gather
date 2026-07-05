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

  describe "invoice.finalized (credit)" do
    context "with a recognized messaging topup line" do
      it "creates the account on demand and records a credit for the invoiced amount" do
        post_event(invoice_event("invoice.finalized", line_amount: 1500))

        expect(response).to have_http_status(:ok)
        expect(Stripe::WebhookEvent.count).to eq(1)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(1)
          account = Messaging::Account.first
          expect(account.community).to eq(community)
          expect(account.currency).to eq("usd")
          expect(account.transactions.count).to eq(1)
          txn = account.transactions.first
          expect(txn.amount_cents).to eq(1500)
          expect(txn.creator).to be_nil
          expect(txn.stripe_invoice_line_item_id).to eq("il_test1")
        end
      end

      it "credits the actual invoiced (prorated) amount, not the price's full unit amount" do
        # A mid-cycle change produces a proration line whose amount differs from price.unit_amount.
        post_event(invoice_event("invoice.finalized", line_amount: 300, unit_amount: 1500))

        with_default_tenant do
          expect(Messaging::Transaction.first.amount_cents).to eq(300)
        end
      end

      it "is idempotent across redelivery of the same line item" do
        event = invoice_event("invoice.finalized", line_amount: 1500)
        post_event(event)
        post_event(event)

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Transaction.count).to eq(1)
          expect(Messaging::Account.count).to eq(1)
        end
      end
    end

    context "with no messaging topup line" do
      it "ignores the event and creates nothing" do
        post_event(invoice_event("invoice.finalized", product: "prod_something_else"))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(0)
          expect(Messaging::Transaction.count).to eq(0)
        end
      end
    end

    context "when the topup subscription is unknown in our DB" do
      it "ignores the event gracefully without creating records" do
        post_event(invoice_event("invoice.finalized", subscription: "sub_unknown"))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(0)
          expect(Messaging::Transaction.count).to eq(0)
        end
      end
    end

    context "when the line currency does not match the account currency" do
      it "gives up without recording a credit" do
        # The US community's account currency is usd; a cad-priced line is a misconfiguration.
        post_event(invoice_event("invoice.finalized", line_currency: "cad"))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(0)
          expect(Messaging::Transaction.count).to eq(0)
        end
      end
    end
  end

  describe "give-up reversal" do
    before { post_event(invoice_event("invoice.finalized", line_amount: 1500)) }

    %w[invoice.marked_uncollectible invoice.voided].each do |type|
      it "reverses the credit with an offsetting transaction on #{type}" do
        post_event(invoice_event(type, line_amount: 1500))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          account = Messaging::Account.first
          expect(account.transactions.count).to eq(2)
          expect(account.balance_cents).to eq(0)
          reversal = account.transactions.find_by(stripe_invoice_line_item_id: "il_test1:reversal")
          expect(reversal.amount_cents).to eq(-1500)
        end
      end
    end

    it "is idempotent across redelivery of the reversal" do
      event = invoice_event("invoice.voided", line_amount: 1500)
      post_event(event)
      post_event(event)

      with_default_tenant do
        expect(Messaging::Transaction.count).to eq(2) # one credit + one reversal
      end
    end

    it "does nothing when there was no credit to reverse" do
      with_default_tenant { Messaging::Transaction.delete_all }
      post_event(invoice_event("invoice.voided", line_amount: 1500))

      with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
    end
  end

  describe "subscription cache sync" do
    it "enqueues a sync for the affected subscription on customer.subscription.updated" do
      expect { post_event(subscription_updated_event) }
        .to have_enqueued_job(Subscription::SyncJob).with(subscription.id)
      expect(response).to have_http_status(:ok)
    end

    it "enqueues a sync on invoice.paid" do
      expect { post_event(invoice_event("invoice.paid", subscription: stripe_sub_id)) }
        .to have_enqueued_job(Subscription::SyncJob).with(subscription.id)
    end

    it "does not enqueue a sync for a subscription unknown in our DB" do
      expect { post_event(subscription_updated_event(id: "sub_unknown")) }
        .not_to have_enqueued_job(Subscription::SyncJob)
    end
  end

  context "with an invalid signature" do
    it "returns 400 and creates nothing" do
      payload = JSON.generate(invoice_event("invoice.finalized"))
      post("/stripe/webhooks", params: payload,
        headers: {"Content-Type" => "application/json", "Stripe-Signature" => "t=123,v1=bogus"})

      expect(response).to have_http_status(:bad_request)
      expect(Stripe::WebhookEvent.count).to eq(0)
      with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
    end
  end

  # Builds a minimal invoice event payload matching the stripe ~> 8.1 shape. unit_amount defaults to
  # line_amount (they differ only for proration lines).
  def invoice_event(type, subscription: topup_sub_id, product: product_id, line_amount: 1000,
    unit_amount: nil, line_currency: "usd")
    {
      id: "evt_test", object: "event", type: type,
      data: {object: {
        id: "in_test", object: "invoice", subscription: subscription, currency: line_currency,
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

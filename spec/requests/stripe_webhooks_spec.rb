# frozen_string_literal: true

require "rails_helper"

describe "Stripe webhooks" do
  let(:community) { Defaults.community } # country_code "US" => currency "usd"
  let(:stripe_sub_id) { "sub_test123" }
  let!(:subscription) { create(:subscription, community: community, stripe_id: stripe_sub_id) }
  let(:product_id) { Settings.stripe.messaging.topup_product_id }
  let(:secret) { Settings.stripe.webhook_signing_secret }

  before { use_apex_domain }

  describe "invoice.paid" do
    context "with a recognized messaging top-up line" do
      it "creates the account on demand and records a top-up" do
        post_event(invoice_paid_event(line_amount: 1500))

        expect(response).to have_http_status(:ok)
        expect(StripeWebhookEvent.count).to eq(1)
        saved = StripeWebhookEvent.first
        expect(saved.event_type).to eq("invoice.paid")
        expect(saved.payload["id"]).to eq("evt_test")
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

      it "is idempotent across redelivery of the same line item" do
        event = invoice_paid_event(line_amount: 1500)
        post_event(event)
        post_event(event)

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Transaction.count).to eq(1)
          expect(Messaging::Account.count).to eq(1)
        end
      end
    end

    context "with no messaging top-up line" do
      it "ignores the event and creates nothing" do
        post_event(invoice_paid_event(product: "prod_something_else"))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(0)
          expect(Messaging::Transaction.count).to eq(0)
        end
      end
    end

    context "when the subscription is unknown in our DB" do
      it "ignores the event gracefully without creating records" do
        post_event(invoice_paid_event(subscription: "sub_unknown"))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(0)
          expect(Messaging::Transaction.count).to eq(0)
        end
      end
    end

    context "when the line currency does not match the account currency" do
      it "gives up without recording a top-up" do
        # The US community's account currency is usd; a cad-priced line is a misconfiguration.
        post_event(invoice_paid_event(line_currency: "cad"))

        expect(response).to have_http_status(:ok)
        with_default_tenant do
          expect(Messaging::Account.count).to eq(0)
          expect(Messaging::Transaction.count).to eq(0)
        end
      end
    end
  end

  context "with an invalid signature" do
    it "returns 400 and creates nothing" do
      payload = JSON.generate(invoice_paid_event)
      post("/stripe/webhooks", params: payload,
        headers: {"Content-Type" => "application/json", "Stripe-Signature" => "t=123,v1=bogus"})

      expect(response).to have_http_status(:bad_request)
      expect(StripeWebhookEvent.count).to eq(0)
      with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
    end
  end

  # Builds a minimal invoice.paid event payload matching the stripe ~> 8.1 shape.
  def invoice_paid_event(subscription: stripe_sub_id, product: product_id, line_amount: 1000,
    line_currency: "usd")
    {
      id: "evt_test", object: "event", type: "invoice.paid",
      data: {object: {
        id: "in_test", object: "invoice", subscription: subscription, currency: line_currency,
        lines: {object: "list", data: [invoice_line(product, line_amount, line_currency)]}
      }}
    }
  end

  def invoice_line(product, amount, currency)
    {
      id: "il_test1", object: "line_item", amount: amount, currency: currency,
      price: {id: "price_test", object: "price", product: product, unit_amount: amount,
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

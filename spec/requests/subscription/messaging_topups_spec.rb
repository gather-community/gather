# frozen_string_literal: true

require "rails_helper"

describe "messaging topup requests" do
  let(:actor) { create(:biller) }
  let(:community) { actor.community }
  let!(:subscription) { create(:subscription, community: community, stripe_id: "sub_main1") }

  def fake_main_sub
    pi = double("Stripe::PaymentIntent", status: "succeeded", next_action: nil, amount: 1800)
    stripe_subscription_double(
      status: "active", pending_setup_intent: nil, default_payment_method: "pm_1",
      latest_invoice: stripe_invoice_double(payment_intent: pi),
      customer: double(id: "cus_1", email: "b@example.com",
        invoice_settings: double(default_payment_method: nil))
    )
  end

  # A finalized invoice carrying one messaging-product line, as the synchronous credit path reads it.
  def fake_finalized_invoice(sub_id, amount)
    product_id = Settings.stripe.messaging.topup_product_id
    stripe_invoice_double(
      id: "in_1", currency: "usd", subscription: sub_id,
      payment_intent: double("Stripe::PaymentIntent", status: "succeeded"), # card paid instantly
      lines: [stripe_invoice_line_double(id: "il_1", amount: amount, currency: "usd",
        product: product_id)]
    )
  end

  before do
    create(:feature_flag, name: "messaging", status: true)
    use_user_subdomain(actor)
    sign_in(actor)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_main_sub)
    allow(Stripe::Price).to receive(:list).and_return(double(data: []))
    allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
  end

  describe "PATCH update" do
    it "creates the topup, credits the wallet synchronously, and sets a green flash with the balance" do
      allow(Stripe::Subscription).to receive(:create).and_return(
        double(id: "sub_topup_new", latest_invoice: fake_finalized_invoice("sub_topup_new", 500))
      )

      patch(subscription_messaging_topup_path, params: {cents: 500}, as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["ok"]).to be(true)
      expect(flash[:success]).to include("$5.00")
      with_default_tenant do
        expect(community.reload.messaging_topup.stripe_id).to eq("sub_topup_new")
        expect(community.messaging_account.balance_cents).to eq(500)
      end
    end

    it "returns a clear reason and the Stripe reference on a Stripe error, crediting nothing" do
      error = Stripe::StripeError.new("Your card was declined.")
      allow(error).to receive(:request_id).and_return("req_123")
      allow(Stripe::Subscription).to receive(:create).and_raise(error)

      patch(subscription_messaging_topup_path, params: {cents: 500}, as: :json)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["ok"]).to be(false)
      expect(response.parsed_body["error"]).to eq("Your card was declined.")
      expect(response.parsed_body["reference"]).to eq("req_123")
      with_default_tenant { expect(Messaging::Transaction.count).to eq(0) }
    end
  end

  describe "POST preview" do
    let!(:topup) { create(:messaging_topup, community: community, stripe_id: "sub_topup_x") }

    before do
      item = stripe_subscription_item_double(id: "si_1", current_period_end: 1.month.from_now.to_i)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        stripe_subscription_double(status: "active", cancel_at_period_end: false, items: [item],
          customer: double(id: "cus_1", invoice_settings: double(default_payment_method: nil)),
          default_payment_method: "pm_1", pending_setup_intent: nil,
          latest_invoice: stripe_invoice_double(
            payment_intent: double("Stripe::PaymentIntent", status: "succeeded", next_action: nil)
          ))
      )
    end

    it "returns the prorated charge for a real change" do
      allow(Stripe::Invoice).to receive(:create_preview).and_return(
        stripe_invoice_double(lines: [stripe_invoice_line_double(proration: true, amount: 342)])
      )

      post(subscription_messaging_topup_preview_path, params: {cents: 1000}, as: :json)

      expect(response.parsed_body["immediate_charge"]).to eq("$3.42")
      expect(response.parsed_body["is_credit"]).to be(false)
    end

    # Reviving a winding-down topup at its existing amount reuses the same Stripe price, so nothing
    # prorates. Returning {} makes the JS show its "from next month" copy rather than promising a
    # charge of $0.00.
    it "returns nothing to preview when no money would move" do
      allow(Stripe::Invoice).to receive(:create_preview).and_return(
        stripe_invoice_double(lines: [stripe_invoice_line_double(proration: false, amount: 500)])
      )

      post(subscription_messaging_topup_preview_path, params: {cents: 500}, as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({})
    end
  end

  describe "DELETE destroy" do
    it "schedules cancellation and returns ok" do
      create(:messaging_topup, community: community, stripe_id: "sub_topup_x")
      allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_main_sub)
      expect(Stripe::Subscription).to receive(:update).with("sub_topup_x", cancel_at_period_end: true)

      delete(subscription_messaging_topup_path, as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["ok"]).to be(true)
    end
  end

  describe "with the messaging feature flag off" do
    before { FeatureFlag.find_by(name: "messaging").update!(status: false) }

    it "refuses to change the topup" do
      expect(Stripe::Subscription).not_to receive(:create)
      expect do
        patch(subscription_messaging_topup_path, params: {cents: 500}, as: :json)
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end

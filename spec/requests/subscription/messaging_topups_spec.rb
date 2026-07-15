# frozen_string_literal: true

require "rails_helper"

describe "messaging topup requests" do
  let(:actor) { create(:biller) }
  let(:community) { actor.community }
  let!(:subscription) { create(:subscription, community: community, stripe_id: "sub_main1") }

  def fake_main_sub
    double("Stripe::Subscription", status: "active",
      latest_invoice: double(payment_intent: double(status: "succeeded", next_action: nil, amount: 1800)),
      pending_setup_intent: nil, default_payment_method: "pm_1",
      customer: double(id: "cus_1", email: "b@example.com",
        invoice_settings: double(default_payment_method: nil)))
  end

  # A finalized invoice carrying one messaging-product line, as the synchronous credit path reads it.
  def fake_finalized_invoice(sub_id, amount)
    product_id = Settings.stripe.messaging.topup_product_id
    double("invoice", id: "in_1", subscription: sub_id, currency: "usd",
      payment_intent: double(status: "succeeded"), # card paid instantly
      lines: double(data: [double(id: "il_1", amount: amount, currency: "usd",
        price: double(product: product_id))]))
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

# frozen_string_literal: true

require "rails_helper"

describe "subscription requests" do
  let(:actor) { create(:biller) }
  let(:community) { actor.community }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  # Builds a Stripe::Subscription double complete enough for sync!/populate, the revive/dead
  # predicates, and rendering the pricing details on the show page (base_rows/email_row/pre_payment).
  def fake_sub(status:, invoice_status: nil, pi_status: nil, pmt_types: %w[card])
    now = Time.current.to_i
    pi = pi_status && double(status: pi_status, next_action: nil, amount: 1000,
      client_secret: "pi_secret", payment_method_types: pmt_types)
    invoice = invoice_status && double(status: invoice_status, payment_intent: pi,
      lines: double(data: [double(period: double(end: 1.month.from_now.to_i))]))
    price = double(unit_amount: 250, currency: "usd",
      recurring: double(interval: "month", interval_count: 1),
      product: double(metadata: {"tier" => "standard"}))
    double("Stripe::Subscription", status: status, latest_invoice: invoice,
      pending_setup_intent: nil, start_date: now, created: now, billing_cycle_anchor: now,
      current_period_end: 1.month.from_now.to_i, discount: nil,
      items: double(data: [double(quantity: 5, price: price)]),
      customer: double(email: "biller@example.com"))
  end

  describe "GET new (self-serve signup)" do
    it "renders the plan picker with prices" do
      allow_any_instance_of(Subscription::PriceCalculator).to receive(:unit_amount_cents).and_return(250)
      get(subscription_new_path)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Set up your Gather subscription").or include("Choose a plan")
    end
  end

  describe "POST create" do
    let(:params) do
      {subscription_signup: {
        tier: "standard", months_per_period: "1", quantity: "5",
        contact_email: "biller@example.com", address_line1: "1 Pond Rd", address_city: "Ann Arbor",
        address_state: "MI", address_postal_code: "48103", address_country: "US"
      }}
    end

    it "registers the subscription and redirects to payment" do
      registrar = instance_double(Subscription::Registrar, register: true)
      allow(Subscription::Registrar).to receive(:new).and_return(registrar)
      allow_any_instance_of(Subscription::PriceCalculator).to receive(:unit_amount_cents).and_return(250)

      post(subscription_create_path, params: params)

      expect(registrar).to have_received(:register)
      expect(response).to redirect_to(subscription_payment_path)
    end

    it "re-renders the form on invalid input" do
      allow_any_instance_of(Subscription::PriceCalculator).to receive(:unit_amount_cents).and_return(250)
      post(subscription_create_path, params: {subscription_signup: params[:subscription_signup]
        .merge(quantity: "0")})
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST start_payment routing" do
    let!(:subscription) { create(:subscription, community: community, stripe_id: "sub_1") }

    it "sends a dead (canceled) subscription to self-serve signup" do
      allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_sub(status: "canceled"))
      post(subscription_start_payment_path)
      expect(response).to redirect_to(subscription_new_path)
    end

    it "sends a past_due sub with a payable invoice to the payment page" do
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        fake_sub(status: "past_due", invoice_status: "open", pi_status: "requires_payment_method")
      )
      post(subscription_start_payment_path)
      expect(response).to redirect_to(subscription_payment_path)
    end
  end

  describe "GET show remediation" do
    let!(:subscription) { create(:subscription, community: community, stripe_id: "sub_1") }

    it "offers re-subscribe for a dead subscription" do
      allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_sub(status: "canceled"))
      get(subscription_path)
      expect(response.body).to include(subscription_new_path)
    end

    it "offers to pay the outstanding invoice for a past_due subscription" do
      allow(Stripe::Subscription).to receive(:retrieve).and_return(
        fake_sub(status: "past_due", invoice_status: "open", pi_status: "requires_payment_method")
      )
      get(subscription_path)
      expect(response.body).to include("past due")
    end
  end

  describe "authorization" do
    it "forbids a non-biller from the signup form" do
      plain = create(:user, community: community)
      use_user_subdomain(plain)
      sign_in(plain)
      expect { get(subscription_new_path) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end

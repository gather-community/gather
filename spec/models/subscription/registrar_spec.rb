# frozen_string_literal: true

require "rails_helper"

describe Subscription::Registrar do
  let(:intent) do
    create(:subscription_intent, tier: "sustainer", price_per_user_cents: 300, months_per_period: 12, quantity: 39)
  end
  let(:product) { double(id: "prod_1", metadata: {"months" => "12", "tier" => "sustainer"}) }
  let(:customer) { double(id: "cus_1") }
  let(:existing_prices) { [] }

  subject(:register) { described_class.new(intent: intent).register }

  before do
    allow(Stripe::Product).to receive(:list).and_return(double(data: [product]))
    allow(Stripe::Price).to receive(:list).and_return(double(data: existing_prices))
    allow(Stripe::Customer).to receive(:search).and_return(double(data: [customer]))
    allow(Stripe::Subscription).to receive(:create).and_return(double(id: "sub_1"))
  end

  it "prices the subscription from the intent's hand-entered per-user price, not the calculator" do
    expect(Subscription::PriceCalculator).not_to receive(:new)
    expect(Stripe::Price).to receive(:create)
      .with(hash_including(unit_amount: 3600, currency: "usd",
        recurring: {interval: "month", interval_count: 12}, product: "prod_1"))
      .and_return(double(id: "price_new"))
    register
    expect(Stripe::Subscription).to have_received(:create)
      .with(hash_including(customer: "cus_1", items: [{price: "price_new", quantity: 39}]))
  end

  context "with a matching price already in Stripe" do
    let(:existing_prices) do
      [double(id: "price_old", product: "prod_1", unit_amount: 3600, currency: "usd",
        recurring: double(interval: "month", interval_count: 12))]
    end

    it "reuses it" do
      expect(Stripe::Price).not_to receive(:create)
      register
      expect(Stripe::Subscription).to have_received(:create)
        .with(hash_including(items: [{price: "price_old", quantity: 39}]))
    end
  end
end

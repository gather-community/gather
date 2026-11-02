# frozen_string_literal: true

require "rails_helper"

describe Messaging::SetupForm do
  let(:community) { Defaults.community }
  let(:admin) { create(:admin, community: community) }
  let(:subscription) do
    build(:subscription, community: community).tap do |s|
      customer = double(id: "cus_1", invoice_settings: double(default_payment_method: nil))
      s.stripe_sub = double(customer: customer,
        default_payment_method: "pm_1")
    end
  end
  let(:params) do
    {package_cents: "1000", legal_name: " Sunny Hill Cohousing Association ", display_name: "Sunny Hill",
     entity_type: "NON_PROFIT", ein: "123456789", street: "1 Main St", city: "Ithaca", state: "ny",
     postal_code: "14850", email: "Admin@Example.com", phone: "(607) 555-1234", website: "", accept_fees: "1"}
  end
  subject(:form) {
    described_class.new(community: community, user: admin, subscription: subscription, params: params)
  }

  def paid_invoice(status: "paid")
    stripe_invoice_double(id: "in_setup", currency: "usd", status: status, subscription: "sub_topup",
      payment_intent: double("Stripe::PaymentIntent",
        status: (status == "paid") ? "succeeded" : "processing"),
      lines: [
        stripe_invoice_line_double(id: "il_pkg", amount: 1000, currency: "usd",
          product: Messaging::Account::PRODUCT_ID),
        double("Stripe::InvoiceLineItem", id: "il_setup", amount: 2400, currency: "usd",
          pricing: double(price_details: double(product: Messaging::Account::PRODUCT_ID, price: "price_x")),
          parent: double(type: "invoice_item_details", invoice_item_details: double(proration: false),
            subscription_item_details: nil))
      ])
  end

  before do
    allow(Stripe::Price).to receive(:list).and_return(double(data: []))
    allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
  end

  describe "validation" do
    it "normalizes the brand details" do
      expect(form).to be_valid
      expect(form.legal_name).to eq("Sunny Hill Cohousing Association")
      expect(form.ein).to eq("12-3456789")
      expect(form.state).to eq("NY")
      expect(form.email).to eq("admin@example.com")
      expect(form.phone).to eq("+16075551234")
    end

    it "requires the admin to accept that the setup fee isn't refundable" do
      params[:accept_fees] = "0"
      expect(form).not_to be_valid
      expect(form.errors[:accept_fees]).to be_present
    end

    it "rejects an EIN that isn't 9 digits" do
      params[:ein] = "12-345"
      expect(form).not_to be_valid
      expect(form.errors[:ein]).to eq(["must be 9 digits, like 12-3456789"])
    end

    it "only offers packages that cover the fixed monthly costs" do
      expect(form.package_options.pluck(:cents)).to eq([500, 1000, 2000])
    end

    it "rejects a package it doesn't offer" do
      params[:package_cents] = "200"
      expect(form).not_to be_valid
      expect(form.errors[:package_cents]).to be_present
    end

    it "rejects public companies and sole proprietors" do
      params[:entity_type] = "SOLE_PROPRIETOR"
      expect(form).not_to be_valid
    end
  end

  describe "#save" do
    it "charges setup and the first month together, credits both, and starts submitting" do
      expect(Stripe::Subscription).to receive(:create).with(hash_including(
        add_invoice_items: [hash_including(price_data: hash_including(unit_amount: 2400))]
      )).and_return(double(id: "sub_topup", latest_invoice: paid_invoice))

      expect { expect(form.save).to be(true) }.to have_enqueued_job(Messaging::AdvanceRegistrationJob)

      registration = community.reload.messaging_registration
      expect(registration).to be_awaiting_payment
      expect(registration.stripe_invoice_id).to eq("in_setup")
      expect(registration.paid_at).to be_present
      expect(registration.ein).to eq("12-3456789")
      expect(community.messaging_account.balance_cents).to eq(3400)
      expect(community.messaging_account.transactions.pluck(:description))
        .to contain_exactly("Monthly messaging topup", "Texting setup payment")
    end

    it "waits for a payment that hasn't settled yet (e.g. ACH)" do
      allow(Stripe::Subscription).to receive(:create)
        .and_return(double(id: "sub_topup", latest_invoice: paid_invoice(status: "open")))
      expect { expect(form.save).to be(true) }.not_to have_enqueued_job(Messaging::AdvanceRegistrationJob)
      expect(community.reload.messaging_registration.paid_at).to be_nil
    end

    it "keeps the details as a draft and reports a declined card" do
      allow(Stripe::Subscription).to receive(:create).and_raise(Stripe::CardError.new(
        "Your card was declined.", nil
      ))
      expect(form.save).to be(false)
      expect(form.errors[:base]).to eq(["Your payment didn't go through: Your card was declined."])
      registration = community.reload.messaging_registration
      expect(registration).to be_draft
      expect(registration.legal_name).to eq("Sunny Hill Cohousing Association")
      expect(community.messaging_account).to be_nil
    end
  end
end

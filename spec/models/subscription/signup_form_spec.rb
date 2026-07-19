# frozen_string_literal: true

require "rails_helper"

describe Subscription::SignupForm do
  let(:community) { create(:community, country_code: "US") } # US => usd

  before do
    allow_any_instance_of(Subscription::PriceCalculator).to receive(:unit_amount_cents).and_return(250)
    allow(community).to receive(:billable_seat_count).and_return(7)
  end

  def form(params)
    described_class.new(community: community, params: params)
  end

  let(:valid_params) do
    {tier: "standard", months_per_period: "1", quantity: "12", contact_email: "biller@example.com",
     address_line1: "1 Pond Rd", address_city: "Ann Arbor", address_state: "MI",
     address_postal_code: "48103", address_country: "US"}
  end

  describe "defaults" do
    it "pre-fills seats from the community's billable seat count" do
      expect(described_class.new(community: community).quantity).to eq(7)
    end

    it "defaults to the standard monthly plan" do
      f = described_class.new(community: community)
      expect(f.tier).to eq("standard")
      expect(f.months_per_period).to eq(1)
    end
  end

  describe "validation" do
    it "accepts a well-formed submission" do
      expect(form(valid_params)).to be_valid
    end

    it "rejects a country Gather can't bill in" do
      expect(form(valid_params.merge(address_country: "ZZ"))).not_to be_valid
    end

    it "rejects a tampered tier" do
      expect(form(valid_params.merge(tier: "platinum"))).not_to be_valid
    end

    it "rejects a non-positive seat count" do
      expect(form(valid_params.merge(quantity: "0"))).not_to be_valid
    end

    it "requires a billing email and address" do
      expect(form(valid_params.merge(contact_email: "", address_line1: ""))).not_to be_valid
    end
  end

  describe "payment method types by country" do
    it "offers ACH for the US" do
      expect(form(valid_params).payment_method_types).to eq(%w[us_bank_account card])
    end

    it "offers ACSS for Canada" do
      expect(form(valid_params.merge(address_country: "CA")).payment_method_types).to eq(%w[acss_debit card])
    end

    it "falls back to card elsewhere" do
      expect(form(valid_params.merge(address_country: "GB")).payment_method_types).to eq(%w[card])
    end
  end

  describe "#save" do
    it "registers the built intent and does not persist the form" do
      registrar = instance_double(Subscription::Registrar, register: true)
      expect(Subscription::Registrar).to receive(:new) do |intent:|
        expect(intent).to be_a(Subscription::Intent)
        expect(intent.tier).to eq("standard")
        expect(intent.quantity).to eq(12)
        expect(intent.address_country).to eq("US")
        expect(intent.payment_method_types).to eq(%w[us_bank_account card])
        registrar
      end
      expect(form(valid_params).save).to be(true)
    end

    it "does not register an invalid submission" do
      expect(Subscription::Registrar).not_to receive(:new)
      expect(form(valid_params.merge(quantity: "0")).save).to be(false)
    end
  end
end

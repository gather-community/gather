# frozen_string_literal: true

require "rails_helper"

describe Subscription::Intent do
  let(:community) { build_stubbed(:community, country_code: "US") } # US => usd

  before do
    allow_any_instance_of(Subscription::PriceCalculator).to receive(:unit_amount_cents)
      .and_return(unit_amount)
  end
  let(:unit_amount) { 250 }

  it "derives currency from the community's country" do
    expect(described_class.new(community: community).currency).to eq("usd")
  end

  it "is never persisted or registered" do
    intent = described_class.new(community: community)
    expect(intent.registered?).to be(false)
    expect(intent).not_to respond_to(:save)
  end

  describe "price derivation (mirrors Subscription)" do
    it "computes unit_amount from the calculator and divides for a monthly per-user price" do
      intent = described_class.new(community: community, tier: "standard", months_per_period: 1)
      expect(intent.unit_amount_cents).to eq(250)
      expect(intent.price_per_user_cents).to eq(250)
    end

    it "divides the yearly unit_amount by the period length for a per-user-per-month price" do
      intent = described_class.new(community: community, tier: "standard", months_per_period: 12)
      expect(intent.price_per_user_cents).to eq(250 / 12)
    end

    it "totals quantity * per-user * months, less any discount" do
      intent = described_class.new(community: community, tier: "standard", months_per_period: 1,
        quantity: 10)
      expect(intent.total_per_invoice).to eq(10 * 250 * 1)
    end
  end

  describe "start-date helpers" do
    it "treats a nil start_date as immediate (not future, not backdated)" do
      intent = described_class.new(community: community)
      expect(intent.future?).to be(false)
      expect(intent.backdated?).to be(false)
    end

    it "recognizes a future start date" do
      intent = described_class.new(community: community, start_date: Time.zone.today + 30)
      expect(intent.future?).to be(true)
    end
  end
end

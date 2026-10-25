# frozen_string_literal: true

require "rails_helper"

describe Messaging::CostCalculator do
  # Pin the markup so these specs are about the arithmetic, not the configured knob. Settings is
  # a global, so restore it.
  around do |example|
    original = Settings.messaging.to_h.deep_dup
    Settings.messaging.markup = 0.2
    example.run
    Settings.messaging.merge!(original)
  end

  # A stand-in for the shared FX cache so specs never hit the DB or network. USD is 1.0 (as the
  # real one short-circuits), and we hand any other currency a fixed rate.
  def fake_fx(rate)
    instance_double(Subscription::PricingData).tap do |pd|
      allow(pd).to receive(:exchange_rate) do |cur|
        (cur.to_s == "usd") ? BigDecimal(1) : BigDecimal(rate.to_s)
      end
    end
  end

  def quote(body:, country: "US", currency: "usd", rate: 1)
    described_class.call(body: body, country: country, currency: currency, pricing_data: fake_fx(rate))
  end

  describe "segmentation (via smstools)" do
    it "counts a short GSM message as one segment" do
      q = quote(body: "Potluck at 6!")
      expect(q.segments).to eq(1)
      expect(q.encoding).to eq(:gsm)
      expect(q.characters).to eq(13)
    end

    it "rolls over to a second segment past the GSM single-segment limit" do
      expect(quote(body: "a" * 160).segments).to eq(1)
      expect(quote(body: "a" * 161).segments).to eq(2)
    end

    it "detects Unicode, which one emoji forces, shrinking capacity" do
      expect(quote(body: "Don’t forget").encoding).to eq(:unicode)
      expect(quote(body: "a" * 100).segments).to eq(1)
      expect(quote(body: ("a" * 100) + "\u{1F389}").segments).to eq(2)
    end

    it "treats an empty body as zero segments and zero cost" do
      q = quote(body: "")
      expect(q.segments).to eq(0)
      expect(q.price).to eq(0)
    end
  end

  describe "pricing (fractional cents preserved)" do
    it "keeps the exact sub-cent BigDecimal instead of rounding to a Money cent" do
      # US all-in cost is 0.009/segment; a single segment must stay 0.009 / 0.0108, not $0.01.
      q = quote(body: "Hi")
      expect(q.cost_per_segment).to eq(BigDecimal("0.009"))
      expect(q.price_per_segment).to eq(BigDecimal("0.0108"))
      expect(q.price).to eq(BigDecimal("0.0108"))
      expect(q.price).to be_a(BigDecimal)
    end

    it "multiplies exactly by segment count" do
      q = quote(body: "a" * 200) # 2 segments
      expect(q.segments).to eq(2)
      expect(q.price).to eq(BigDecimal("0.0216"))
    end

    it "stays exact across a bulk quantity, where a per-message round would drift" do
      # 0.0108 x 500 = 5.40 exactly; rounding each message to $0.01 first would give $5.00.
      expect(quote(body: "Hi").price_per_segment * 500).to eq(BigDecimal("5.4"))
    end

    it "reports the provider carrying the country" do
      expect(quote(body: "Hi", country: "US").provider).to eq(:telnyx)
      expect(quote(body: "Hi", country: "GB").provider).to eq(:telnyx)
    end
  end

  describe "FX localization" do
    it "leaves USD untouched (rate 1.0)" do
      q = quote(body: "Hi", currency: "usd")
      expect(q.exchange_rate).to eq(BigDecimal(1))
      expect(q.price_per_segment).to eq(BigDecimal("0.0108"))
      expect(q.currency).to eq("usd")
    end

    it "converts the cost to the billing currency before applying markup" do
      # US cost 0.009 USD, CAD at 1.4 => 0.0126 CAD cost, x1.2 markup = 0.01512 CAD.
      q = quote(body: "Hi", currency: "cad", rate: "1.4")
      expect(q.exchange_rate).to eq(BigDecimal("1.4"))
      expect(q.cost_per_segment).to eq(BigDecimal("0.0126"))
      expect(q.price_per_segment).to eq(BigDecimal("0.01512"))
      expect(q.currency).to eq("cad")
    end

    it "uses the real shared FX cache by default (USD needs no lookup)" do
      # No injected pricing_data: exercises Subscription::PricingData, which short-circuits USD.
      q = described_class.call(body: "Hi", country: "US")
      expect(q.price_per_segment).to eq(BigDecimal("0.0108"))
    end
  end

  describe "#margin" do
    it "is price minus our cost, in the billing currency" do
      q = quote(body: "a" * 200, currency: "cad", rate: "1.4")
      expect(q.margin).to eq(q.price - q.cost)
      expect(q.margin).to be > 0
    end
  end

  it "normalizes a lowercase country code" do
    expect(quote(body: "Hi", country: "us").provider).to eq(:telnyx)
  end

  it "raises for an unsupported country rather than guessing a price" do
    expect { quote(body: "Hi", country: "FR") }
      .to raise_error(Messaging::Rates::UnsupportedCountryError, /not supported for FR/)
  end
end

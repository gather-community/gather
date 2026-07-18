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

  def quote(body:, country: "US")
    described_class.call(body: body, country: country)
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

    it "detects Unicode and its shorter segment limit" do
      q = quote(body: "Don’t forget") # curly quote forces UCS-2
      expect(q.encoding).to eq(:unicode)
    end

    it "makes one emoji force Unicode, shrinking capacity" do
      expect(quote(body: "a" * 100).segments).to eq(1)
      expect(quote(body: ("a" * 100) + "\u{1F389}").segments).to eq(2)
    end

    it "treats an empty body as zero segments and zero cost" do
      q = quote(body: "")
      expect(q.segments).to eq(0)
      expect(q.price).to eq(Money.from_amount(0, "USD"))
    end
  end

  describe "pricing" do
    it "prices at the country's all-in cost times segments times markup" do
      # US all-in cost is 0.009/segment; x1.2 markup = 0.0108; x2 segments = 0.0216 -> $0.02.
      q = quote(body: "a" * 200)
      expect(q.segments).to eq(2)
      expect(q.cost_per_segment).to eq(BigDecimal("0.009"))
      expect(q.price_per_segment).to eq(BigDecimal("0.0108"))
      expect(q.price).to eq(Money.from_amount(0.02, "USD"))
      expect(q.cost).to eq(Money.from_amount(0.018, "USD").round)
    end

    it "keeps the sub-cent per-segment price so bulk sends stay accurate" do
      # A single US segment rounds to a cent, but 500 of them shouldn't: 0.0108 x 500 = 5.40.
      q = quote(body: "Hi")
      expect(q.price_per_segment * 500).to eq(BigDecimal("5.4"))
    end

    it "reports the provider carrying the country" do
      expect(quote(body: "Hi", country: "US").provider).to eq(:telnyx)
      expect(quote(body: "Hi", country: "NZ").provider).to eq(:twilio)
    end

    it "denominates in USD, the currency providers bill us in" do
      expect(quote(body: "Hi", country: "GB").currency).to eq("USD")
      expect(quote(body: "Hi", country: "GB").price.currency.iso_code).to eq("USD")
    end
  end

  describe "#margin" do
    it "is price minus our cost" do
      q = quote(body: "a" * 500, country: "NZ") # dear enough that a cent-level margin survives
      expect(q.margin).to eq(q.price - q.cost)
      expect(q.margin.cents).to be > 0
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

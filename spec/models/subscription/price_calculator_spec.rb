# frozen_string_literal: true

require "rails_helper"

# A stand-in for PricingData so the math is exercised without the DB or network.
FakePricingData = Struct.new(:inflation_factor, :rates, keyword_init: true) do
  def exchange_rate(currency)
    rates.fetch(currency.to_s.downcase)
  end
end

describe Subscription::PriceCalculator do
  describe ".localize (Method 2 — Dynamic Localized Interval)" do
    def localize(usd, rate)
      described_class.localize(BigDecimal(usd.to_s), BigDecimal(rate.to_s))
    end

    it "rounds to a clean local interval for a sub-10 rate (EUR)" do
      # raw .23 -> clean .25 -> round(1.242/.25)=5 -> 1.25
      expect(localize("1.35", "0.92")).to eq(BigDecimal("1.25"))
    end

    it "rounds to a clean local interval for a >=100 rate (JPY)" do
      # raw 37.5 -> clean round(0.75)*50=50 -> round(202.5/50)=4 -> 200
      expect(localize("1.35", "150")).to eq(BigDecimal("200"))
    end

    it "rounds to a clean local interval for a 10..100 rate (MXN)" do
      # raw 4.25 -> clean round(0.85)*5=5 -> round(22.95/5)=5 -> 25
      expect(localize("1.35", "17")).to eq(BigDecimal("25"))
    end

    it "is a no-op for USD (rate 1.0) on a 0.25-multiple input" do
      expect(localize("2.00", "1")).to eq(BigDecimal("2.00"))
    end

    it "falls back to the raw interval when the clean interval rounds to zero" do
      # rate 0.001: raw = 0.00025; clean = round(0.001)*0.25 = 0 -> fallback to raw.
      # final = round((1*0.001)/0.00025)*0.00025 = 4*0.00025 = 0.001
      expect(localize("1.00", "0.001")).to eq(BigDecimal("0.001"))
    end

    it "rounds half up on an interval boundary" do
      # rate 1.0, input 1.125 -> (1.125/0.25)=4.5 -> half-up 5 -> 1.25
      expect(localize("1.125", "1")).to eq(BigDecimal("1.25"))
    end
  end

  describe ".floor_to_step" do
    it "floors down to the nearest step" do
      expect(described_class.floor_to_step("2.42", "0.25")).to eq(BigDecimal("2.25"))
      expect(described_class.floor_to_step("3.63", "0.25")).to eq(BigDecimal("3.50"))
    end

    it "leaves exact multiples unchanged" do
      expect(described_class.floor_to_step("2.50", "0.25")).to eq(BigDecimal("2.50"))
    end
  end

  describe "#usd_monthly_price" do
    def usd_price(tier, factor)
      data = FakePricingData.new(inflation_factor: BigDecimal(factor.to_s), rates: {})
      described_class.new(tier: tier, currency: "usd", months_per_period: 1, data: data).usd_monthly_price
    end

    it "inflation-adjusts the anchor then floors to $0.25" do
      expect(usd_price("budget", "1.21")).to eq(BigDecimal("1.00"))    # 1.21 -> 1.00
      expect(usd_price("standard", "1.21")).to eq(BigDecimal("2.25"))  # 2.42 -> 2.25
      expect(usd_price("sustainer", "1.21")).to eq(BigDecimal("3.50")) # 3.63 -> 3.50
    end
  end

  describe "#unit_amount_cents" do
    # Isolate the period/discount/cents logic from the localization math.
    def calc(currency, months, monthly)
      c = described_class.new(tier: "standard", currency: currency, months_per_period: months,
        data: FakePricingData.new(inflation_factor: BigDecimal(1), rates: {}))
      allow(c).to receive(:localized_monthly_price).and_return(BigDecimal(monthly))
      c
    end

    it "bills the localized monthly price for a monthly period" do
      expect(calc("eur", 1, "1.25").unit_amount_cents).to eq(125)
      expect(calc("jpy", 1, "200").unit_amount_cents).to eq(200) # zero-decimal currency
    end

    it "bills months * price * 90% (10% off) for a yearly period" do
      expect(calc("eur", 12, "1.25").unit_amount_cents).to eq(1350) # 1.25*12*0.9 = 13.50
      expect(calc("jpy", 12, "200").unit_amount_cents).to eq(2160)  # 200*12*0.9 = 2160
    end
  end

  describe ".supported_currencies" do
    it "is derived from the country->currency map and includes usd" do
      expect(described_class.supported_currencies).to include("usd", "eur", "cad")
      expect(described_class.supported_currencies).to eq(described_class.supported_currencies.uniq)
    end
  end
end

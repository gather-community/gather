# frozen_string_literal: true

require "rails_helper"

describe Subscription::PricingData do
  let(:fetcher) { instance_double(Subscription::PricingDataFetcher) }
  subject(:data) { described_class.new(fetcher: fetcher) }

  describe "#exchange_rate" do
    it "returns 1.0 for USD without any fetch or DB read" do
      expect(fetcher).not_to receive(:fetch_exchange_rate!)
      expect(data.exchange_rate("usd")).to eq(BigDecimal(1))
    end

    it "returns the stored rate when present, without fetching" do
      Subscription::ExchangeRate.create!(currency: "eur", rate: BigDecimal("0.92"), fetched_at: Time.current)
      expect(fetcher).not_to receive(:fetch_exchange_rate!)
      expect(data.exchange_rate("eur")).to eq(BigDecimal("0.92"))
    end

    it "syncs once when absent, then returns the fetched rate" do
      record = Subscription::ExchangeRate.new(currency: "eur", rate: BigDecimal("0.9"))
      expect(fetcher).to receive(:fetch_exchange_rate!).with("eur").and_return(record)
      expect(data.exchange_rate("eur")).to eq(BigDecimal("0.9"))
    end

    it "reports to Sentry and hard-fails when absent and the sync fetch fails" do
      allow(fetcher).to receive(:fetch_exchange_rate!)
        .and_raise(Subscription::PricingDataFetcher::FetchError, "boom")
      expect(Gather::ErrorReporter.instance).to receive(:report)
      expect { data.exchange_rate("eur") }.to raise_error(described_class::MissingDataError)
    end
  end

  describe "#inflation_factor" do
    def reading(year, value)
      Subscription::InflationReading.create!(year: year, index_value: BigDecimal(value),
        fetched_at: Time.current)
    end

    it "is latest / base when both readings are present, without fetching" do
      reading(2020, "250.0")
      reading(2026, "300.0")
      expect(fetcher).not_to receive(:fetch_inflation!)
      expect(fetcher).not_to receive(:fetch_latest_inflation!)
      expect(data.inflation_factor).to eq(BigDecimal("300.0") / BigDecimal("250.0"))
    end

    it "syncs the latest reading when only the base year is stored (never yields factor 1.0)" do
      reading(2020, "250.0")
      latest = Subscription::InflationReading.new(year: 2026, index_value: BigDecimal("300.0"))
      expect(fetcher).to receive(:fetch_latest_inflation!).and_return(latest)
      expect(data.inflation_factor).to eq(BigDecimal("300.0") / BigDecimal("250.0"))
    end

    it "hard-fails (never defaults to 1.0) when the base reading is missing and its fetch fails" do
      reading(2026, "300.0") # a current reading exists, but base 2020 does not
      allow(fetcher).to receive(:fetch_inflation!)
        .and_raise(Subscription::PricingDataFetcher::FetchError, "no base")
      expect(Gather::ErrorReporter.instance).to receive(:report)
      expect { data.inflation_factor }.to raise_error(described_class::MissingDataError)
    end
  end
end

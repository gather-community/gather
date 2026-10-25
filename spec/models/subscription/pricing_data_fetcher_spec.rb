# frozen_string_literal: true

require "rails_helper"

describe Subscription::PricingDataFetcher do
  let(:fx_client) { instance_double(Subscription::ExchangeRateClient) }
  let(:cpi_client) { instance_double(Subscription::CpiClient) }
  subject(:fetcher) { described_class.new(exchange_rate_client: fx_client, cpi_client: cpi_client) }

  describe "#fetch_exchange_rate!" do
    it "upserts and returns the rate record" do
      allow(fx_client).to receive(:usd_rate).with("eur").and_return(BigDecimal("0.92"))
      record = fetcher.fetch_exchange_rate!("EUR")
      expect(record).to be_persisted
      expect(record.currency).to eq("eur")
      expect(record.rate).to eq(BigDecimal("0.92"))
      expect(Subscription::ExchangeRate.where(currency: "eur").count).to eq(1)
    end

    it "updates the existing row rather than duplicating" do
      Subscription::ExchangeRate.create!(currency: "eur", rate: BigDecimal("0.80"), fetched_at: 1.day.ago)
      allow(fx_client).to receive(:usd_rate).and_return(BigDecimal("0.92"))
      fetcher.fetch_exchange_rate!("eur")
      expect(Subscription::ExchangeRate.where(currency: "eur").count).to eq(1)
      expect(Subscription::ExchangeRate.find_by(currency: "eur").rate).to eq(BigDecimal("0.92"))
    end
  end

  describe "#fetch_inflation!" do
    it "upserts the annual index under the given year" do
      allow(cpi_client).to receive(:annual_index).with(2020).and_return(BigDecimal("258.811"))
      record = fetcher.fetch_inflation!(2020)
      expect(record.year).to eq(2020)
      expect(record.index_value).to eq(BigDecimal("258.811"))
    end
  end

  describe "#fetch_latest_inflation!" do
    it "upserts the latest monthly index under its own year" do
      allow(cpi_client).to receive(:latest_index).and_return([2026, BigDecimal("320.5")])
      record = fetcher.fetch_latest_inflation!
      expect(record.year).to eq(2026)
      expect(record.index_value).to eq(BigDecimal("320.5"))
    end
  end
end

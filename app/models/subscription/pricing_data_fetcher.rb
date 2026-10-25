# frozen_string_literal: true

module Subscription
  # Shared fetch-and-upsert code for the external pricing inputs (exchange rates and CPI). Used by
  # BOTH the nightly RefreshPricingDataJob and the synchronous fallback in PricingData, so there is
  # exactly one place that talks to the external APIs and writes the cache. Each method fetches from
  # the injected client (raising FetchError on any network/parse trouble), upserts the row, and
  # returns the record.
  class PricingDataFetcher
    # Raised by the API clients (and re-surfaced here) on any failure to obtain a value. Callers
    # decide what to do: the nightly job reports and moves on; PricingData reports and hard-fails.
    FetchError = Class.new(StandardError)

    def initialize(exchange_rate_client: ExchangeRateClient.new, cpi_client: CpiClient.new)
      @exchange_rate_client = exchange_rate_client
      @cpi_client = cpi_client
    end

    # Fetch and cache the USD->currency rate. Returns the ExchangeRate record.
    def fetch_exchange_rate!(currency)
      currency = currency.to_s.downcase
      rate = @exchange_rate_client.usd_rate(currency)
      record = ExchangeRate.find_or_initialize_by(currency: currency)
      record.update!(rate: rate, fetched_at: Time.current)
      record
    end

    # Fetch and cache the finalized annual-average CPI index for a specific year (used for the
    # 2020 base). Returns the InflationReading record.
    def fetch_inflation!(year)
      index = @cpi_client.annual_index(year)
      upsert_inflation(year, index)
    end

    # Fetch and cache the latest available monthly CPI index, stored under its own year (used for
    # the "current" numerator so pricing never waits for a year-end annual average). Returns the
    # InflationReading record.
    def fetch_latest_inflation!
      year, index = @cpi_client.latest_index
      upsert_inflation(year, index)
    end

    private

    def upsert_inflation(year, index)
      record = InflationReading.find_or_initialize_by(year: year)
      record.update!(index_value: index, fetched_at: Time.current)
      record
    end
  end
end

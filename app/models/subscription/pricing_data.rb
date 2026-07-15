# frozen_string_literal: true

module Subscription
  # Read accessor the PriceCalculator depends on for the two external inputs it needs: the current
  # inflation factor and a currency's exchange rate. Reads the locally-cached value first (stale is
  # tolerated — the nightly RefreshPricingDataJob keeps it fresh); only when a needed value is
  # absent does it fall back to a synchronous fetch via the SAME shared PricingDataFetcher. If that
  # fetch fails and nothing is stored, it reports to Sentry and raises a hard MissingDataError.
  #
  # Two deliberate asymmetries:
  #   * USD short-circuits to rate 1.0 — it's the base currency (definitional), so it never depends
  #     on the rate feed and is never stored.
  #   * Inflation NEVER defaults. A missing inflation reading that can't be fetched hard-fails; it
  #     must never fall back to a factor of 1.0, which would silently bill 2020 anchor prices.
  class PricingData
    MissingDataError = Class.new(StandardError)

    def initialize(fetcher: PricingDataFetcher.new)
      @fetcher = fetcher
    end

    # Units of `currency` per 1 USD. USD is always exactly 1.0 and is never fetched or stored.
    def exchange_rate(currency)
      currency = currency.to_s.downcase
      return BigDecimal(1) if currency == "usd"
      stored = ExchangeRate.find_by(currency: currency)
      return stored.rate if stored
      sync { @fetcher.fetch_exchange_rate!(currency) }.rate
    end

    # index(latest available) / index(2020). No `|| 1` anywhere — missing data hard-fails.
    def inflation_factor
      latest_inflation_index / base_inflation_index
    end

    private

    def base_inflation_index
      stored = InflationReading.find_by(year: PriceCalculator::BASE_YEAR)
      return stored.index_value if stored
      sync { @fetcher.fetch_inflation!(PriceCalculator::BASE_YEAR) }.index_value
    end

    # The most recent stored reading newer than the base year, else a fresh sync-fetch of the
    # latest monthly index. Guards against having ONLY the base-year row (which would wrongly
    # yield a factor of 1.0).
    def latest_inflation_index
      newest = InflationReading.where("year > ?", PriceCalculator::BASE_YEAR).order(year: :desc).first
      return newest.index_value if newest
      sync { @fetcher.fetch_latest_inflation! }.index_value
    end

    # Runs a fetch; on failure reports to Sentry and hard-fails so callers never quote a wrong price.
    def sync
      yield
    rescue PricingDataFetcher::FetchError => e
      Gather::ErrorReporter.instance.report(e)
      raise MissingDataError, e.message
    end
  end
end

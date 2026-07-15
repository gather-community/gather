# frozen_string_literal: true

module Subscription
  # Nightly job that refreshes the cached pricing inputs (US CPI + USD exchange rates) so the
  # self-serve pricing pages never have to fetch synchronously. Runs globally — the data is not
  # tenant-scoped. Each fetch is independent: one currency's (or the CPI's) FetchError is reported
  # to Sentry and the run continues, so a single flaky endpoint doesn't starve the rest of the cache.
  class RefreshPricingDataJob < ApplicationJob
    def perform
      fetcher = PricingDataFetcher.new
      report { fetcher.fetch_inflation!(PriceCalculator::BASE_YEAR) }
      report { fetcher.fetch_latest_inflation! }
      (PriceCalculator.supported_currencies - ["usd"]).each do |currency|
        report { fetcher.fetch_exchange_rate!(currency) }
      end
    end

    private

    def report
      yield
    rescue PricingDataFetcher::FetchError => e
      Gather::ErrorReporter.instance.report(e)
    end
  end
end

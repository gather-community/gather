# frozen_string_literal: true

require "net/http"

module Subscription
  # Thin HTTP client for current USD-based exchange rates. Defaults to open.er-api.com (free, no
  # key required, wide currency coverage including AED/HKD/IDR/MYR/THB/SGD). Base URL and optional
  # API key come from Settings.pricing.exchange_rate, so a paid provider can be swapped in without
  # touching callers. Injected into PricingDataFetcher; stubbed with WebMock in specs.
  #
  # One `/latest/USD` response carries every currency, so the full table is memoized per client
  # instance: a single RefreshPricingDataJob run (one client, many currencies) makes one HTTP call.
  class ExchangeRateClient
    def usd_rate(currency)
      code = currency.to_s.upcase
      rates.fetch(code) do
        raise PricingDataFetcher::FetchError, "no exchange rate for #{code}"
      end
    end

    private

    def rates
      @rates ||= fetch_rates
    end

    def fetch_rates
      body = get("#{base_url}/USD")
      json = JSON.parse(body)
      raw = json["rates"]
      raise PricingDataFetcher::FetchError, "malformed exchange rate response" unless raw.is_a?(Hash)
      raw.transform_values { |v| BigDecimal(v.to_s) }
    rescue JSON::ParserError, ArgumentError => e
      raise PricingDataFetcher::FetchError, "could not parse exchange rate response: #{e.message}"
    end

    def get(url)
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(apikey: api_key) if api_key.present?
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      raise PricingDataFetcher::FetchError, "exchange rate API returned #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      res.body
    rescue SocketError, Timeout::Error, SystemCallError => e
      raise PricingDataFetcher::FetchError, "exchange rate API request failed: #{e.message}"
    end

    def base_url
      Settings.pricing.exchange_rate.base_url
    end

    def api_key
      Settings.pricing.exchange_rate.api_key
    end
  end
end

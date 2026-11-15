# frozen_string_literal: true

require "net/http"

module Subscription
  # Thin HTTP client for US CPI-U index values from the BLS public data API (series CUUR0000SA0 by
  # default — CPI-U, US city average, all items, not seasonally adjusted). Base URL, series id, and
  # registration key come from Settings.pricing.cpi. A FRED client with the same interface could be
  # swapped in via Settings. Injected into PricingDataFetcher; stubbed with WebMock in specs.
  #
  # The BLS v2 API is a POST endpoint: the series id, year range, and registration key go in a JSON
  # body (a GET is redirected to the human-facing website). It returns data points as
  # {year, period, periodName, value}, most-recent first. period "M13" is the finalized annual
  # average; "M01".."M12" are monthly.
  class CpiClient
    ANNUAL_PERIOD = "M13"
    MONTHLY_PERIOD = /\AM(0[1-9]|1[0-2])\z/

    # The finalized annual-average index for a specific year (used for the 2020 base). Requires the
    # request to ask for annual averages (see #post).
    def annual_index(year)
      point = series(year, year).find { |d| d["period"] == ANNUAL_PERIOD && numeric?(d["value"]) }
      raise PricingDataFetcher::FetchError, "no annual CPI for #{year}" if point.nil?
      BigDecimal(point.fetch("value"))
    end

    # The most recent monthly index available, as [year, index_value]. Queries the current and
    # prior year so it still returns a value early in a year before any current-year data exists.
    # Skips non-numeric points (BLS reports gaps as "-", e.g. a data-collection lapse).
    def latest_index
      this_year = Time.current.year
      point = series(this_year - 1, this_year).find do |d|
        MONTHLY_PERIOD.match?(d["period"]) && numeric?(d["value"])
      end
      raise PricingDataFetcher::FetchError, "no recent monthly CPI available" if point.nil?
      [Integer(point.fetch("year")), BigDecimal(point.fetch("value"))]
    end

    private

    # Returns the series data array (most-recent first) for the inclusive year range.
    def series(start_year, end_year)
      body = post(start_year, end_year)
      json = JSON.parse(body)
      data = json.dig("Results", "series", 0, "data")
      unless data.is_a?(Array)
        raise PricingDataFetcher::FetchError, "malformed CPI response: #{json["status"]}"
      end
      data
    rescue JSON::ParserError, KeyError => e
      raise PricingDataFetcher::FetchError, "could not parse CPI response: #{e.message}"
    end

    def numeric?(value)
      value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
    end

    # BLS v2 is a POST endpoint: series id, year range, key, and options go in a JSON body.
    # annualaverage: true asks BLS to include the M13 annual-average rows we use for the base year.
    def post(start_year, end_year)
      uri = URI.parse(base_url)
      payload = {seriesid: [series_id], startyear: start_year.to_s, endyear: end_year.to_s,
                 annualaverage: true}
      payload[:registrationkey] = api_key if api_key.present?
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = payload.to_json
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
      raise PricingDataFetcher::FetchError, "CPI API returned #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      res.body
    rescue SocketError, Timeout::Error, SystemCallError => e
      raise PricingDataFetcher::FetchError, "CPI API request failed: #{e.message}"
    end

    def base_url
      Settings.pricing.cpi.base_url
    end

    def series_id
      Settings.pricing.cpi.series_id
    end

    def api_key
      Settings.pricing.cpi.api_key
    end
  end
end

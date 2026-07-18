# frozen_string_literal: true

module Subscription
  # Computes the per-seat subscription price for a (tier, currency, billing period) from the 2020
  # USD anchors, adjusted for inflation and localized to the target currency.
  #
  # The pipeline:
  #   1. Start from the tier's 2020 USD monthly anchor.
  #   2. Inflation-adjust it (index(latest) / index(2020)) and FLOOR to the nearest $0.25.
  #   3. Localize to the target currency via "Method 2 — Dynamic Localized Interval": convert the
  #      $0.25 step to the local scale, clean it to a natural local denomination, and round the
  #      converted price to that clean interval. USD is a no-op (rate 1.0).
  #   4. For yearly billing, multiply by the number of months and bake in a flat 10% discount.
  #      Convert the final decimal to Stripe's smallest currency unit via the money gem (which
  #      handles zero-decimal currencies like JPY correctly).
  #
  # The inflation factor and exchange rate come from a PricingData accessor (locally-cached values
  # with a synchronous fetch fallback), injected so the math is testable without touching the DB or
  # the network. Missing inflation data is a HARD error (never silently falls back to 2020 prices);
  # see PricingData.
  class PriceCalculator
    TIER_ANCHORS_2020_USD = {
      "budget" => BigDecimal("1.00"),
      "standard" => BigDecimal("2.00"),
      "sustainer" => BigDecimal("3.00")
    }.freeze
    TIERS = TIER_ANCHORS_2020_USD.keys.freeze

    BASE_YEAR = 2020
    USD_STEP = BigDecimal("0.25")
    YEARLY_DISCOUNT = BigDecimal("0.90")
    HALF_UP = BigDecimal::ROUND_HALF_UP

    # Every currency Gather can bill in, derived from the country->currency map. Includes "usd".
    def self.supported_currencies
      Community::COUNTRY_CURRENCIES.values.uniq
    end

    def initialize(tier:, currency:, months_per_period:, data: PricingData.new)
      @tier = tier.to_s
      @currency = currency.to_s.downcase
      @months = Integer(months_per_period)
      @data = data
    end

    # Inflation-adjusted USD monthly per-seat price, floored to the nearest $0.25.
    def usd_monthly_price
      anchor = TIER_ANCHORS_2020_USD.fetch(@tier)
      self.class.floor_to_step(anchor * @data.inflation_factor, USD_STEP)
    end

    # Localized (Method 2) monthly per-seat price in the target currency.
    def localized_monthly_price
      self.class.localize(usd_monthly_price, @data.exchange_rate(@currency))
    end

    # The Stripe Price unit_amount in smallest currency units, for the chosen billing period.
    # Monthly bills the localized monthly price; yearly bills months * price * 90% (10% off).
    def unit_amount_cents
      monthly = localized_monthly_price
      amount = (@months == 1) ? monthly : (monthly * @months * YEARLY_DISCOUNT)
      Money.from_amount(amount, @currency).cents
    end

    # Floor `amount` DOWN to the nearest multiple of `step` (both coerced to BigDecimal).
    def self.floor_to_step(amount, step)
      amount = BigDecimal(amount.to_s)
      step = BigDecimal(step.to_s)
      (amount / step).floor * step
    end

    # Method 2 — Dynamic Localized Interval. Converts `usd_price` at `rate`, rounding to a clean
    # local denomination derived from the converted $0.25 step. Final round is nearest (half-up).
    def self.localize(usd_price, rate)
      usd_price = BigDecimal(usd_price.to_s)
      rate = BigDecimal(rate.to_s)
      raw_interval = USD_STEP * rate
      clean_interval =
        if rate >= 100
          (raw_interval / 50).round(0, HALF_UP) * 50
        elsif rate >= 10
          (raw_interval / 5).round(0, HALF_UP) * 5
        else
          (raw_interval / USD_STEP).round(0, HALF_UP) * USD_STEP
        end
      clean_interval = raw_interval if clean_interval.zero?
      ((usd_price * rate) / clean_interval).round(0, HALF_UP) * clean_interval
    end
  end
end

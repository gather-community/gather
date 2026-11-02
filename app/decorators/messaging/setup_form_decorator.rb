# frozen_string_literal: true

module Messaging
  # The costs and package choices shown on the texting setup page.
  class SetupFormDecorator < ApplicationDecorator
    delegate_all

    # Rows for the setup fee breakdown, as [label, amount].
    def setup_fee_rows
      Fees.setup_items.map do |key, cents|
        [h.t("messaging.fees.#{key}"), money(cents)]
      end
    end

    def setup_fee
      money(Fees.setup_cents)
    end

    def monthly_fixed
      money(Fees.monthly_fixed_cents)
    end

    # What 100 single-segment texts cost the community, e.g. "$1.08". One text costs about a cent, which
    # money formatting would round to $0.01.
    def price_per_100_texts
      h.format_money(price_per_segment * 100, currency: Fees::CURRENCY)
    end

    # The package radio options, as [label, cents]. Each label says roughly how many texts are left for
    # after the fixed monthly costs.
    def package_collection
      package_options.map do |option|
        texts = texts_for(option[:cents])
        [h.t("messaging.setups.new.package_option", amount: option[:label], count: texts), option[:cents]]
      end
    end

    private

    def money(cents)
      h.format_money(cents.to_d / 100, currency: Fees::CURRENCY)
    end

    # Single-segment texts the rest of a package pays for, rounded down to a multiple of 10 so it reads
    # as the estimate it is.
    def texts_for(cents)
      dollars = (cents - Fees.monthly_fixed_cents).to_d / 100
      ((dollars / price_per_segment).floor / 10) * 10
    end

    def price_per_segment
      @price_per_segment ||= CostCalculator.call(body: "x", country: "US", currency: Fees::CURRENCY)
        .price_per_segment
    end
  end
end

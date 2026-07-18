# frozen_string_literal: true

module Messaging
  # The single source of truth for which countries we can send SMS to, which provider carries
  # each, and our all-in cost per segment. It stitches the per-provider rate tables (currently
  # just Providers::Telnyx) into one country => provider map, and is what CostCalculator and the
  # top-up flow query. The multi-provider machinery stays even with one provider today, so adding
  # another later is just a new adapter in PROVIDERS.
  #
  # Two design notes:
  #
  # - Every price is a worst-case, all-in cost per segment: base price plus, where the provider
  #   bills them separately (US/CA), the dearest carrier's pass-through fee. We can't know the
  #   recipient's carrier at pricing time without a paid per-number lookup, so we price against
  #   the most expensive carrier rather than risk under-charging. The markup (applied in
  #   CostCalculator) sits on top of this.
  #
  # - A country maps to exactly one provider. If two provider tables ever claim the same
  #   country, that's a configuration bug and we raise at load rather than pick one silently.
  module Rates
    class UnsupportedCountryError < StandardError; end

    # Every SMS provider we price against. One entry today; the conflict check in #table guards
    # the invariant that no two providers claim the same country once there's more than one.
    PROVIDERS = [Providers::Telnyx].freeze

    class << self
      def supported?(country_code)
        table.key?(normalize(country_code))
      end

      # Uppercase ISO country codes we can price and send to, sorted for stable display.
      def supported_countries
        table.keys.sort
      end

      # The provider class carrying this country, or raises UnsupportedCountryError.
      def provider_for(country_code)
        table.fetch(normalize(country_code)) do
          raise UnsupportedCountryError, "SMS is not supported for #{normalize(country_code)}"
        end
      end

      # Our all-in cost for one segment to this country, as a BigDecimal in #currency.
      def cost_per_segment(country_code)
        code = normalize(country_code)
        provider_for(code).cost_per_segment(code)
      end

      def currency(country_code)
        provider_for(country_code).currency
      end

      private

      def normalize(country_code)
        country_code.to_s.upcase
      end

      # country_code => provider class, built once from every provider's table. Raises if two
      # providers claim the same country.
      def table
        @table ||= PROVIDERS.each_with_object({}) do |provider, map|
          provider.countries.each do |code|
            if map.key?(code)
              raise "#{code} is claimed by both #{map[code]} and #{provider}"
            end
            map[code] = provider
          end
        end
      end
    end
  end
end

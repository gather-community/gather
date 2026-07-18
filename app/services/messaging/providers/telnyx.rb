# frozen_string_literal: true

module Messaging
  module Providers
    # Telnyx carries most of our supported countries. Prices are per "message part" (= segment)
    # in USD.
    #
    # SOURCING / CONFIDENCE — these figures need a sanity check against the Telnyx Mission
    # Control portal, which shows live rates, because Telnyx removed international pricing from
    # its public site. Verified 2026-07-18:
    #   US - SOLID. $0.004 base + carrier fee. Live page telnyx.com/pricing/messaging.
    #        Worst-case carrier fee is US Cellular $0.005, so all-in $0.009.
    #   CA - base SOLID ($0.004), carrier-fee table is 2024-archived (medium confidence).
    #        Worst-case carrier fee is Bell/Virgin $0.016, so all-in $0.020.
    #   AU - 2024-archived, medium confidence. $0.07 all-in (no separate carrier fees).
    #   GB - 2024-archived, medium confidence. $0.04 all-in (no separate carrier fees).
    # See Messaging::Rates for the worst-case-carrier rationale.
    class Telnyx < Base
      RATES = {
        "US" => "0.009",
        "CA" => "0.020",
        "AU" => "0.07",
        "GB" => "0.04"
      }.freeze

      def self.rates
        RATES
      end
    end
  end
end

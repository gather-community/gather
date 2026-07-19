# frozen_string_literal: true

module Messaging
  module Providers
    # Telnyx carries most of our supported countries. Prices are per "message part" (= segment)
    # in USD.
    #
    # SOURCING / CONFIDENCE — Telnyx removed international pricing from its public site, so these
    # come from the logged-in Mission Control portal, which shows live rates.
    #   US - SOLID. Verified 2026-07-18 (telnyx.com/pricing/messaging, still public). $0.004 base
    #        + carrier fee; worst-case is US Cellular $0.005, so all-in $0.009.
    #   CA - SOLID. Verified 2026-07-18 from the portal. Long-code SMS send base $0.0025; worst-
    #        case send-side (MT) carrier fee is Rogers/Fido $0.008845, so all-in $0.011345.
    #   AU - SOLID. Verified 2026-07-18 from the portal. Long-code SMS send $0.05 all-in (no
    #        separate carrier fees).
    #   GB - SOLID. Verified 2026-07-18 from the portal. Long-code SMS send $0.055 all-in (no
    #        separate carrier fees).
    # See Messaging::Rates for the worst-case-carrier rationale.
    class Telnyx < Base
      RATES = {
        "US" => "0.009",
        "CA" => "0.011345",
        "AU" => "0.05",
        "GB" => "0.055"
      }.freeze

      def self.rates
        RATES
      end
    end
  end
end

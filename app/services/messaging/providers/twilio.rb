# frozen_string_literal: true

module Messaging
  module Providers
    # Twilio carries the countries Telnyx doesn't. Right now that's just New Zealand: Telnyx
    # only offers one-way alphanumeric-sender SMS there, not the two-way long-code sending we
    # need, so NZ routes to Twilio. Prices are per segment in USD.
    #
    # SOURCING / CONFIDENCE — verified 2026-07-18:
    #   NZ - SOLID. $0.105 all-in (no separate carrier fees), confirmed against Twilio's live
    #        Pricing API (pricing.twilio.com/v1/Messaging/Countries/NZ).
    class Twilio < Base
      RATES = {
        "NZ" => "0.105"
      }.freeze

      def self.rates
        RATES
      end
    end
  end
end

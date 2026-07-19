# frozen_string_literal: true

module Messaging
  # Given a message body and a destination country, works out how many SMS segments the body
  # occupies and what we charge to send it. This is the entry point the compose UI and the
  # send/debit path call.
  #
  #   quote = Messaging::CostCalculator.call(body: "Potluck at 6!", country: "US")
  #   quote.segments   #=> 1
  #   quote.price      #=> #<BigDecimal 0.0108>   what we charge, per message, markup included
  #   quote.provider   #=> :telnyx
  #
  # Localized to a community's currency by passing `currency:` (defaults to USD, our providers'
  # billing currency):
  #
  #   Messaging::CostCalculator.call(body: "...", country: "US", currency: "cad").price
  #
  # FRACTIONAL CENTS ARE DELIBERATE. A single US segment costs about nine tenths of a US cent, so
  # every monetary field on the Quote is an exact BigDecimal in major currency units (e.g.
  # 0.0108), NOT a Money — rounding a per-message figure to the nearest cent would throw away
  # most of it and make the markup vanish. Callers that actually charge should aggregate the
  # whole send (all recipients x segments) and round once at the end; the wallet
  # (Messaging::Transaction) stores integer cents, so per-message debits must accrue rather than
  # round each message up to a cent.
  #
  # PIPELINE: cost per segment comes from Messaging::Rates in USD; it's converted to the billing
  # currency via the shared FX cache (Subscription::PricingData, the same rates the subscription
  # price calculator uses), then multiplied by the markup (Settings.messaging.markup) and the
  # segment count. Segment counting and encoding come from the smstools gem.
  class CostCalculator
    # One quote. Every monetary field is an exact BigDecimal in `currency` (major units) — see the
    # class comment on why these aren't Money.
    #   cost  - what the message costs us
    #   price - what we charge the community (cost x markup)
    Quote = Struct.new(:country, :provider, :encoding, :characters, :segments, :currency,
      :exchange_rate, :cost_per_segment, :price_per_segment, :cost, :price, keyword_init: true) do
      def margin
        price - cost
      end
    end

    def self.call(body:, country:, currency: "usd", pricing_data: Subscription::PricingData.new)
      new(body: body, country: country, currency: currency, pricing_data: pricing_data).calculate
    end

    def initialize(body:, country:, currency: "usd", pricing_data: Subscription::PricingData.new)
      @body = body.to_s
      @country = country.to_s.upcase
      @currency = currency.to_s.downcase
      @pricing_data = pricing_data
    end

    # Raises Messaging::Rates::UnsupportedCountryError if we don't serve the destination country —
    # callers should gate on Messaging::Rates.supported? before offering a send.
    def calculate
      cost_per_segment = usd_cost_per_segment * exchange_rate
      price_per_segment = cost_per_segment * (1 + markup)
      Quote.new(
        country: @country,
        provider: Rates.provider_for(@country).key,
        encoding: detection.encoding,
        characters: detection.length,
        segments: segments,
        currency: @currency,
        exchange_rate: exchange_rate,
        cost_per_segment: cost_per_segment,
        price_per_segment: price_per_segment,
        cost: cost_per_segment * segments,
        price: price_per_segment * segments
      )
    end

    private

    # Our provider cost per segment, in the providers' own currency (USD).
    def usd_cost_per_segment
      Rates.cost_per_segment(@country)
    end

    # Units of the billing currency per 1 USD. USD short-circuits to exactly 1 with no lookup.
    def exchange_rate
      @exchange_rate ||= @pricing_data.exchange_rate(@currency)
    end

    def detection
      @detection ||= SmsTools::EncodingDetection.new(@body)
    end

    # smstools reports 1 part for an empty body; an empty message sends nothing and costs
    # nothing, so treat it as zero segments.
    def segments
      @body.empty? ? 0 : detection.concatenated_parts
    end

    def markup
      BigDecimal(Settings.messaging.markup.to_s)
    end
  end
end

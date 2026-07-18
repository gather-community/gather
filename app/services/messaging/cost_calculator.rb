# frozen_string_literal: true

module Messaging
  # Given a message body and a destination country, works out how many SMS segments the body
  # occupies and what we charge to send it. This is the entry point the compose UI and the
  # send/debit path call.
  #
  #   quote = Messaging::CostCalculator.call(body: "Potluck at 6!", country: "US")
  #   quote.segments  #=> 1
  #   quote.price     #=> #<Money $0.01>   (what we charge, markup included)
  #   quote.provider  #=> :telnyx
  #
  # The price is our all-in provider cost per segment (Messaging::Rates) times the number of
  # segments times the markup (Settings.messaging.markup). Segment counting comes from the
  # smstools gem, which detects GSM-7 vs Unicode and counts concatenated parts.
  #
  # Prices are in USD — both providers bill our account in USD regardless of destination. That
  # is not necessarily the community's currency; reconciling the two (and FX) is deliberately
  # out of scope here.
  class CostCalculator
    # One quote. cost_per_segment / price_per_segment are BigDecimal so a sub-cent figure
    # survives; cost / price are Money, rounded to the cent that actually gets charged.
    #   cost  - what the send costs us
    #   price - what we charge the community (cost x markup)
    Quote = Struct.new(:country, :provider, :encoding, :characters, :segments, :currency,
      :cost_per_segment, :price_per_segment, :cost, :price, keyword_init: true) do
      def margin
        price - cost
      end
    end

    def self.call(body:, country:)
      new(body: body, country: country).calculate
    end

    def initialize(body:, country:)
      @body = body.to_s
      @country = country.to_s.upcase
    end

    # Raises Messaging::Rates::UnsupportedCountryError if we don't serve the country — callers
    # should gate on Messaging::Rates.supported? before offering a send.
    def calculate
      cost_per_segment = Rates.cost_per_segment(@country)
      price_per_segment = cost_per_segment * (1 + markup)
      Quote.new(
        country: @country,
        provider: Rates.provider_for(@country).key,
        encoding: detection.encoding,
        characters: detection.length,
        segments: segments,
        currency: currency,
        cost_per_segment: cost_per_segment,
        price_per_segment: price_per_segment,
        cost: money(cost_per_segment * segments),
        price: money(price_per_segment * segments)
      )
    end

    private

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

    def currency
      Rates.currency(@country)
    end

    def money(amount)
      Money.from_amount(amount, currency)
    end
  end
end

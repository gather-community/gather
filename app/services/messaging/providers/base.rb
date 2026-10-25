# frozen_string_literal: true

module Messaging
  module Providers
    # Base class for an SMS provider (currently just Telnyx). Each provider owns the set of
    # countries it carries and our all-in cost per segment for each — see the RATES constant on
    # a subclass. Pricing is a hardcoded table rather than a live API lookup: providers don't
    # expose carrier pass-through fees programmatically (Telnyx has no pricing API at all), so a
    # fetched price would be wrong anyway. Sending will hang off these same classes later; for
    # now they answer only "what does a segment cost?".
    #
    # Which provider carries which country is resolved by Messaging::Rates, not here. A country
    # belongs to exactly one provider.
    class Base
      class << self
        # country_code (uppercase ISO-3166 alpha-2) => all-in cost per segment as a decimal
        # string, in the currency named by CURRENCY. "All-in" means base price plus, where the
        # provider bills them on top (US/CA), the worst-case carrier pass-through fee across
        # carriers — we can't know the recipient's carrier without a paid lookup, so we price
        # against the dearest.
        def rates
          raise NotImplementedError, "#{name} must define RATES"
        end

        # ISO code of the currency the rates are denominated in. Both providers bill our account
        # in USD regardless of destination, so this is USD for now, but it stays a per-provider
        # value rather than a global assumption.
        def currency
          "USD"
        end

        # Short symbol naming the provider, e.g. :telnyx. Used for display and (later) routing a
        # send to the right adapter.
        def key
          name.demodulize.underscore.to_sym
        end

        def serves?(country_code)
          rates.key?(country_code)
        end

        def countries
          rates.keys
        end

        # Our all-in cost for one segment to this country, as a BigDecimal. Raises if this
        # provider doesn't carry the country — Messaging::Rates should have routed elsewhere.
        def cost_per_segment(country_code)
          value = rates.fetch(country_code) do
            raise ArgumentError, "#{name} does not carry #{country_code}"
          end
          BigDecimal(value)
        end
      end
    end
  end
end

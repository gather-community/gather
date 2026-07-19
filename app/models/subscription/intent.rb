# frozen_string_literal: true

module Subscription
  # An in-memory description of the subscription a community is about to create: what they picked
  # (tier, billing period, seats) plus who/where to bill. Built by SignupForm and handed to
  # Registrar, which turns it into a real Stripe subscription.
  #
  # Deliberately NOT persisted. It used to be a staff-created AR record, which meant stale rows hung
  # around forever after registration and confused the picture of what a community was actually on.
  # Now it lives only for the duration of the request that registers the subscription. Bespoke
  # pricing, if we ever need it again, should come from Stripe coupons / promotion codes rather than
  # a stored per-community price.
  #
  # The price isn't stored either — it's computed from (tier, currency, months_per_period) by
  # PriceCalculator. The derived price methods mirror Subscription's, so SubscriptionDecorator can
  # render an Intent and a live Subscription identically.
  class Intent
    include ActiveModel::Model

    ADDRESS_ATTRIBS = %i[
      address_line1 address_line2 address_city address_state address_postal_code address_country
    ].freeze

    attr_accessor :community, :contact_email, :tier, :months_per_period, :quantity,
      :payment_method_types, :discount_percent, :start_date, *ADDRESS_ATTRIBS

    delegate :name, to: :community, prefix: true

    # Currency is derived from the community's country, not chosen or stored. Named `currency` so
    # SubscriptionDecorator can treat Intent and Subscription polymorphically.
    def currency
      community.default_currency
    end

    def registered?
      false
    end

    def incomplete?
      false
    end

    # What Stripe will charge per seat per billing period (yearly already has its 10% baked in).
    def unit_amount_cents
      @unit_amount_cents ||= PriceCalculator.new(tier: tier, currency: currency,
        months_per_period: months_per_period).unit_amount_cents
    end

    # Per seat per month. Mirrors Subscription#price_per_user_cents, which divides the Stripe
    # unit_amount by the period length.
    def price_per_user_cents
      unit_amount_cents / months_per_period
    end

    def total_per_invoice
      quantity * price_per_user_cents * months_per_period * (1 - (discount_percent || 0) / 100)
    end

    # Self-serve subscriptions always start immediately, so these are only ever true for a
    # hand-built Intent with an explicit start_date (e.g. a staff-run migration in the console).
    def future?
      start_date.present? && start_date > Time.zone.today
    end

    def backdated?
      start_date.present? && start_date < Time.zone.today
    end

    def start_date_to_timestamp
      start_date.present? ? Time.zone.parse(start_date.to_s).to_i : nil
    end
  end
end

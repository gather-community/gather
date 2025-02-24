# frozen_string_literal: true

module Subscription
  # Models a subscription of Gather product itself.
  class Subscription < ApplicationRecord
    # Override suffix
    self.table_name = "subscriptions"

    acts_as_tenant :cluster

    attr_accessor :stripe_sub

    belongs_to :community, inverse_of: :subscription

    delegate :name, to: :community, prefix: true

    def registered?
      true
    end

    # Fetches data from Stripe
    def populate
      return if stripe_id.nil?

      self.stripe_sub = Stripe::Subscription.retrieve(
        id: stripe_id,
        expand: %w[customer.invoice_settings items.data.price.product latest_invoice.payment_intent
                   pending_setup_intent]
      )
      Rails.logger.info("Loaded subscription: #{stripe_sub}")
      stripe_sub
    end

    def status
      stripe_sub&.status
    end

    def active?
      status == "active"
    end

    def incomplete?
      status == "incomplete"
    end

    def incomplete_expired?
      status == "incomplete_expired"
    end

    def past_due?
      status == "past_due"
    end

    def unpaid?
      status == "unpaid"
    end

    def canceled?
      status == "canceled"
    end

    # Even if a sub is active, it may still need a payment method.
    # This happens for subscriptions that start at a future date since we don't prorate
    # and don't do a $0 invoice, we instead use a SetupIntent, and so Stripe considers
    # the sub active even though the SetupIntent still hasn't been finished.
    def needs_payment_method?
      return nil if stripe_sub.nil?

      active? && payment_or_setup_intent&.status == "requires_payment_method"
    end

    def payment_processing?
      return nil if stripe_sub.nil?

      stripe_sub.latest_invoice&.payment_intent&.status == "processing" ||
        stripe_sub.pending_setup_intent&.status == "processing" ||
        # There seems to be a short delay between when the SetupIntent is marked 'succeeded'
        # and when the subscription default_payment_method gets updated. If we load the page
        # inside that delay, we should say 'processing'.
        (needs_payment_method? && stripe_sub.pending_setup_intent&.status == "succeeded")
    end

    def payment_method_types
      return nil if stripe_sub.nil?

      payment_or_setup_intent.payment_method_types
    end

    def payment_requires_microdeposits?
      return nil if stripe_sub.nil?

      payment_or_setup_intent&.next_action&.type == "verify_with_microdeposits"
    end

    def contact_email
      return nil if stripe_sub.nil?

      stripe_sub.customer.email
    end

    def start_date
      return nil if stripe_sub.nil?

      stamp = backdated? ? stripe_sub.start_date : stripe_sub.billing_cycle_anchor
      Time.zone.at(stamp).to_date
    end

    def backdated?
      return nil if stripe_sub.nil?

      stripe_sub.start_date < stripe_sub.created
    end

    def future?
      no_invoice?
    end

    def no_invoice?
      return nil if stripe_sub.nil?

      # If subscription is post-dated, there won't be an invoice since we set proration_behavior to none.
      stripe_sub.latest_invoice.nil?
    end

    def next_payment_date
      return nil if stripe_sub.nil?

      Time.zone.at(stripe_sub&.current_period_end).to_date
    end

    def last_invoice_amount_cents
      return nil if stripe_sub.nil?
      return 0 if no_invoice?

      stripe_sub.latest_invoice.payment_intent.amount
    end

    def client_secret
      return nil if stripe_sub.nil?

      payment_or_setup_intent.client_secret
    end

    def months_per_period
      return nil if stripe_sub.nil?

      stripe_sub.items.data[0].price.recurring.interval_count
    end

    def price_per_user_cents
      return nil if stripe_sub.nil?

      stripe_sub.items.data[0].price.unit_amount / months_per_period
    end

    def total_per_invoice
      return nil if stripe_sub.nil?

      quantity * price_per_user_cents * months_per_period * (1 - ((discount_percent || 0) / 100))
    end

    def currency
      return nil if stripe_sub.nil?

      stripe_sub.items.data[0].price.currency
    end

    def tier
      return nil if stripe_sub.nil?

      stripe_sub.items.data[0].price.product.metadata["tier"]
    end

    def quantity
      return nil if stripe_sub.nil?

      stripe_sub.items.data[0].quantity
    end

    def discount_percent
      return nil if stripe_sub.nil?

      stripe_sub.discount&.coupon&.percent_off
    end

    def address_line1
      return nil if stripe_sub.nil?

      stripe_sub.customer.address.line1
    end

    def address_line2
      return nil if stripe_sub.nil?

      stripe_sub.customer.address.line2
    end

    def address_city
      return nil if stripe_sub.nil?

      stripe_sub.customer.address.city
    end

    def address_state
      return nil if stripe_sub.nil?

      stripe_sub.customer.address.state
    end

    def address_postal_code
      return nil if stripe_sub.nil?

      stripe_sub.customer.address.postal_code
    end

    def address_country
      return nil if stripe_sub.nil?

      stripe_sub.customer.address.country
    end

    private

    def payment_or_setup_intent
      if no_invoice?
        stripe_sub.pending_setup_intent
      else
        stripe_sub.latest_invoice.payment_intent
      end
    end
  end
end

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
      self.stripe_sub = Stripe::Subscription.retrieve(id: stripe_id, expand: %w[customer latest_invoice.payment_intent])
    end

    def status
      stripe_sub&.status
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

    def contact_email
      stripe_sub.customer.email
    end

    def start_date
      Time.zone.at(stripe_sub.start_date).to_date
    end

    def last_invoice_amount_cents
      stripe_sub.latest_invoice.payment_intent.amount
    end

    def client_secret
      stripe_sub.latest_invoice.payment_intent.client_secret
    end

    def months_per_period
      stripe_sub.items.data[0].price.recurring.interval_count
    end

    def price_per_user_cents
      stripe_sub.items.data[0].price.unit_amount
    end

    def currency
      stripe_sub.items.data[0].price.currency
    end

    def quantity
      stripe_sub.items.data[0].quantity
    end

    def address_line1
      stripe_sub.customer.address.line1
    end

    def address_line2
      stripe_sub.customer.address.line2
    end

    def address_city
      stripe_sub.customer.address.city
    end

    def address_state
      stripe_sub.customer.address.state
    end

    def address_postal_code
      stripe_sub.customer.address.postal_code
    end

    def address_country
      stripe_sub.customer.address.country
    end
  end
end
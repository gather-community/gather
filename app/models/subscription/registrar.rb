# frozen_string_literal: true

module Subscription
  # Registers a given subscription with Stripe
  class Registrar
    include ActiveModel::Model

    ADDRESS_FIELDS = %i[city country line1 line2 postal_code state].freeze

    attr_accessor :subscription, :customer, :price

    def register
      self.price = find_or_create_price
      self.customer = find_or_create_customer
      stripe_subscription = create_subscription
      subscription.update_to_registered!(stripe_subscription.id)
    end

    private

    def find_or_create_price
      match = Stripe::Price.list.data.detect do |price|
        price.product == Settings.stripe.product_id &&
          price.unit_amount == subscription.price_per_user_cents &&
          price.currency == subscription.currency &&
          price.recurring.interval == "month" &&
          price.recurring.interval_count == subscription.months_per_period
      end
      match || create_price
    end

    def create_price
      Stripe::Price.create(
        unit_amount: subscription.price_per_user_cents,
        currency: subscription.currency,
        recurring: {interval: "month", interval_count: subscription.months_per_period},
        product: Settings.stripe.product_id
      )
    end

    def find_or_create_customer
      matches = Stripe::Customer.search(query: "email:'#{@subscription.contact_email}'").data
      raise "Mutliple customers found for #{@subscription.contact_email}" if matches.size > 1
      matches[0] || create_customer
    end

    def create_customer
      Stripe::Customer.create(
        email: subscription.contact_email,
        description: subscription.community_name,
        address: ADDRESS_FIELDS.map { |f| [f, subscription["address_#{f}"]] }.to_h
      )
    end

    def create_subscription
      Stripe::Subscription.create(
        customer: customer.id,
        items: [{price: price.id}],
        payment_behavior: "default_incomplete",
        payment_settings: {save_default_payment_method: "on_subscription"}
      )
    end
  end
end

# frozen_string_literal: true

module Subscription
  # Registers a given subscription with Stripe
  # Deletes any previous subscriptions for the community
  class Registrar
    include ActiveModel::Model

    ADDRESS_FIELDS = %i[city country line1 line2 postal_code state].freeze

    attr_accessor :intent, :customer, :price

    def register
      self.price = find_or_create_price
      self.customer = find_or_create_customer
      Subscription.where(community: intent.community).destroy_all
      stripe_subscription = create_subscription
      Subscription.create!(community: intent.community, stripe_id: stripe_subscription.id)
    end

    private

    def find_or_create_price
      match = Stripe::Price.list.data.detect do |price|
        price.product == Settings.stripe.product_id &&
          price.unit_amount == intent.price_per_user_cents &&
          price.currency == intent.currency &&
          price.recurring.interval == "month" &&
          price.recurring.interval_count == intent.months_per_period
      end
      match || create_price
    end

    def create_price
      Stripe::Price.create(
        unit_amount: intent.price_per_user_cents,
        currency: intent.currency,
        recurring: {interval: "month", interval_count: intent.months_per_period},
        product: Settings.stripe.product_id
      )
    end

    def find_or_create_customer
      matches = Stripe::Customer.search(query: "email:'#{intent.contact_email}'").data
      raise "Mutliple customers found for #{intent.contact_email}" if matches.size > 1
      matches[0] || create_customer
    end

    def create_customer
      Stripe::Customer.create(
        email: intent.contact_email,
        name: intent.community_name,
        address: ADDRESS_FIELDS.map { |f| [f, intent["address_#{f}"]] }.to_h
      )
    end

    def create_subscription
      Stripe::Subscription.create(
        customer: customer.id,
        items: [{price: price.id, quantity: intent.quantity}],
        payment_behavior: "default_incomplete",
        backdate_start_date: intent.start_date < Time.zone.today ? Time.zone.parse(intent.start_date.to_s).to_i : nil,
        billing_cycle_anchor: intent.start_date > Time.zone.today ? Time.zone.parse(intent.start_date.to_s).to_i : nil,
        payment_settings: {
          save_default_payment_method: "on_subscription",
          payment_method_types: %w[us_bank_account acss_debit]
        }
      )
    end
  end
end

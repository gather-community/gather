# frozen_string_literal: true

module Subscription
  # Registers a given subscription with Stripe
  # Deletes any previous subscriptions for the community
  class Registrar
    include ActiveModel::Model

    ADDRESS_FIELDS = %i[city country line1 line2 postal_code state].freeze

    attr_accessor :intent, :customer, :price, :product, :coupon

    def register
      self.product = find_or_create_product
      self.price = find_or_create_price
      self.customer = find_or_create_customer
      self.coupon = find_or_create_coupon if intent.discount_percent.present?
      Subscription.where(community: intent.community).destroy_all
      stripe_subscription = create_subscription
      Subscription.create!(community: intent.community, stripe_id: stripe_subscription.id)
    end

    private

    def find_or_create_product
      match = Stripe::Product.list(active: true).data.detect do |product|
        product.metadata["months"] == intent.months_per_period.to_s &&
          product.metadata["tier"] == intent.tier
      end
      match || create_product
    end

    def create_product
      months = intent.months_per_period == 1 ? "1 month" : "#{intent.months_per_period} months"
      Stripe::Product.create(
        name: "Gather user seat, #{months}, #{intent.tier} tier",
        metadata: {
          months: intent.months_per_period,
          tier: intent.tier
        }
      )
    end

    def find_or_create_price
      match = Stripe::Price.list.data.detect do |price|
        price.product == product.id &&
          price.unit_amount == intent.price_per_user_cents * intent.months_per_period &&
          price.currency == intent.currency &&
          price.recurring.interval == "month" &&
          price.recurring.interval_count == intent.months_per_period
      end
      match || create_price
    end

    def create_price
      Stripe::Price.create(
        unit_amount: intent.price_per_user_cents * intent.months_per_period,
        currency: intent.currency,
        recurring: {interval: "month", interval_count: intent.months_per_period},
        product: product.id
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
        description: intent.community_name,
        address: ADDRESS_FIELDS.index_with { |f| intent["address_#{f}"] }
      )
    end

    def find_or_create_coupon
      match = Stripe::Coupon.list.data.detect do |coupon|
        coupon.amount_off.nil? && coupon.duration == "forever" && (coupon.percent_off - intent.discount_percent).abs < 0.0001
      end
      match || create_coupon
    end

    def create_coupon
      Stripe::Coupon.create(
        duration: "forever",
        percent_off: intent.discount_percent,
        name: "Discount"
      )
    end

    def create_subscription
      Stripe::Subscription.create(
        customer: customer.id,
        coupon: coupon&.id,
        items: [{price: price.id, quantity: intent.quantity}],
        payment_behavior: "default_incomplete",
        backdate_start_date: intent.backdated? ? intent.start_date_to_timestamp : nil,
        billing_cycle_anchor: intent.future? ? intent.start_date_to_timestamp : nil,
        # For future start dates, we don't want to prorate, because in our system this means they are migrating and
        # they've already paid for the previous billing cycle.
        proration_behavior: intent.future? ? "none" : nil,
        payment_settings: {
          save_default_payment_method: "on_subscription",
          payment_method_types: intent.payment_method_types
        }
      )
    end
  end
end

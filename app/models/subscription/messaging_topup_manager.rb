# frozen_string_literal: true

module Subscription
  # Orchestrates the Stripe side of a community's monthly messaging topup: creating/finding the
  # monthly price under the messaging product, creating/updating/canceling the dedicated topup
  # subscription, and previewing the immediate charge for a change. Mirrors Registrar's style.
  #
  # The topup is its own monthly Stripe subscription (never an item on the base plan) so it always
  # bills monthly regardless of the base plan's cadence. The messaging wallet is credited by
  # Stripe::TopupProcessor when each invoice finalizes.
  #
  # Proration cases (all monthly-scale — no case ever produces an annual lump):
  #   * First activation (None -> $Y): a brand-new monthly subscription anchored now, so a full
  #     month is invoiced and charged immediately. The wallet is usable today. No proration.
  #   * Increase ($Y -> $Z): the item price is swapped with proration_behavior "always_invoice", so
  #     Stripe invoices the prorated difference for the remainder of this month immediately; the full
  #     $Z bills each month after.
  #   * Decrease ($Y -> $Z): same swap, but the proration is a credit toward the next invoice.
  #   * Remove (-> None): cancel_at_period_end so they keep the month already paid for; no charge and
  #     the wallet balance is untouched.
  class MessagingTopupManager
    include ActiveModel::Model

    attr_accessor :community, :subscription

    # subscription is the community's populated base Subscription::Subscription (its Stripe customer
    # and default payment method fund the topup).
    def initialize(community:, subscription:)
      @community = community
      @subscription = subscription
    end

    def topup
      @topup ||= community.messaging_topup
    end

    # Points the monthly topup at `cents` per month. Creates the topup subscription on first use
    # (full month billed now), else swaps the item price and invoices the proration immediately.
    def set_amount!(cents)
      price = find_or_create_price(cents, required_currency)
      if existing_item
        Stripe::SubscriptionItem.update(existing_item.id, price: price.id,
          proration_behavior: "always_invoice")
        topup
      else
        create_subscription(price)
      end
    end

    # Schedules removal at the end of the current paid month. Idempotent-ish: a no-op if none exists.
    def cancel!
      return if topup.nil?
      Stripe::Subscription.update(topup.stripe_id, cancel_at_period_end: true)
    end

    # Previews the immediate proration for changing an existing topup to `cents`. Returns
    # {immediate_charge_cents:, next_bill_date:, currency:}. First activation (no existing sub) has
    # no proration — the caller shows the full-month copy instead.
    def preview(cents)
      return nil if existing_item.nil?
      price = find_or_create_price(cents, required_currency)
      invoice = Stripe::Invoice.upcoming(
        customer: customer.id,
        subscription: topup.stripe_id,
        subscription_items: [{id: existing_item.id, price: price.id}],
        subscription_proration_behavior: "create_prorations"
      )
      {
        immediate_charge_cents: invoice.lines.data.select { |l| l.proration }.sum(&:amount),
        next_bill_date: topup.next_bill_date,
        currency: required_currency
      }
    end

    private

    def required_currency
      currency = community.default_currency
      raise "No currency mapping for country_code=#{community.country_code}" if currency.blank?
      currency
    end

    def customer
      subscription.stripe_sub.customer
    end

    def find_or_create_price(cents, currency)
      product_id = Messaging::Account::PRODUCT_ID
      match = Stripe::Price.list(product: product_id, active: true).data.detect do |price|
        price.unit_amount == cents && price.currency == currency &&
          price.recurring&.interval == "month" && price.recurring&.interval_count == 1
      end
      match || Stripe::Price.create(
        unit_amount: cents,
        currency: currency,
        recurring: {interval: "month", interval_count: 1},
        product: product_id
      )
    end

    def create_subscription(price)
      stripe_sub = Stripe::Subscription.create(
        customer: customer.id,
        items: [{price: price.id}],
        default_payment_method: subscription.default_payment_method_id,
        payment_settings: {save_default_payment_method: "on_subscription"}
      )
      community.create_messaging_topup!(stripe_id: stripe_sub.id)
    end

    # The current topup subscription's single item, or nil when there's no topup yet.
    def existing_item
      return nil if topup.nil?
      topup.populate if topup.stripe_sub.nil?
      topup.item
    end
  end
end

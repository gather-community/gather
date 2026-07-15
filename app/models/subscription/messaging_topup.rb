# frozen_string_literal: true

# == Schema Information
#
# Table name: subscription_messaging_topups
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  stripe_id    :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
module Subscription
  # A community's recurring monthly messaging topup, modeled as its own Stripe subscription
  # (separate from the main Gather Subscription). Kept separate so it always bills monthly no matter
  # the base plan's cadence — an annual base plan would otherwise force the topup to bill a whole
  # year at once. Each monthly invoice credits the community's Messaging::Account wallet (see
  # Stripe::TopupProcessor). This local record just maps the Stripe subscription id back to the
  # community/cluster so webhooks can resolve the tenant; live details are read via #populate.
  class MessagingTopup < ApplicationRecord
    # Round monthly topup tiers per currency, in *major* currency units. USD is the reference
    # ([2, 5, 10, 20]); the others are approximate round equivalents — adjust as FX shifts. Covers
    # every currency in Community::COUNTRY_CURRENCIES. Amounts are converted to minor units with
    # Money.from_amount, which handles zero-decimal currencies (e.g. jpy: from_amount(300).cents ==
    # 300) and Stripe's HUF "whole-number" quirk (whole major units always yield cents ending in 00).
    AMOUNTS_BY_CURRENCY = {
      "usd" => [2, 5, 10, 20], "eur" => [2, 5, 10, 20], "gbp" => [2, 5, 10, 20],
      "chf" => [2, 5, 10, 20], "aud" => [3, 8, 15, 30], "cad" => [3, 7, 15, 30],
      "nzd" => [3, 8, 16, 32], "sgd" => [3, 7, 14, 28], "aed" => [7, 18, 37, 73],
      "hkd" => [15, 40, 80, 160], "bgn" => [4, 10, 20, 40], "brl" => [10, 25, 50, 100],
      "czk" => [50, 120, 240, 480], "dkk" => [15, 35, 70, 140], "huf" => [700, 1800, 3600, 7200],
      "idr" => [30_000, 75_000, 150_000, 300_000], "inr" => [170, 420, 850, 1700],
      "jpy" => [300, 750, 1500, 3000], "mxn" => [40, 100, 200, 400], "myr" => [9, 22, 45, 90],
      "nok" => [20, 55, 110, 220], "pln" => [8, 20, 40, 80], "ron" => [9, 23, 46, 92],
      "sek" => [20, 55, 110, 220], "thb" => [70, 180, 350, 700]
    }.freeze

    acts_as_tenant :cluster

    attr_accessor :stripe_sub

    belongs_to :community, inverse_of: :messaging_topup

    # The selectable topup tiers for a currency as [{cents:, label:}], or [] if the currency has no
    # mapping (in which case the topup UI is hidden). cents is what we charge/store; label is the
    # human-formatted amount for the radio options.
    def self.options_for(currency)
      (AMOUNTS_BY_CURRENCY[currency] || []).map do |amount|
        money = Money.from_amount(amount, currency)
        {cents: money.cents.to_i, label: money.format}
      end
    end

    # Fetches live data from Stripe. Leaves stripe_sub populated for the request.
    def populate
      return if stripe_id.nil?
      self.stripe_sub = Stripe::Subscription.retrieve(
        id: stripe_id,
        expand: %w[items.data.price latest_invoice.payment_intent customer.invoice_settings]
      )
    end

    def item
      stripe_sub&.items&.data&.first
    end

    def amount_cents
      item&.price&.unit_amount
    end

    def currency
      item&.price&.currency
    end

    def status
      stripe_sub&.status
    end

    def active?
      status == "active"
    end

    def past_due?
      status == "past_due"
    end

    # True once a removal has been scheduled: the topup keeps running until the paid-through date,
    # then Stripe cancels it. See MessagingTopupManager#cancel!.
    def canceling?
      stripe_sub&.cancel_at_period_end == true
    end

    def payment_processing?
      stripe_sub&.latest_invoice&.payment_intent&.status == "processing"
    end

    def next_bill_date
      return nil if stripe_sub.nil?
      Time.zone.at(stripe_sub.current_period_end).to_date
    end
  end
end

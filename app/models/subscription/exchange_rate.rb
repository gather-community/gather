# frozen_string_literal: true

# == Schema Information
#
# Table name: subscription_exchange_rates
#
#  id         :bigint           not null, primary key
#  currency   :string           not null
#  rate       :decimal(18, 8)   not null
#  fetched_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
module Subscription
  # Cached USD->currency exchange rate (units of `currency` per 1 USD). Refreshed nightly by
  # RefreshPricingDataJob, with a synchronous fetch fallback via PricingDataFetcher. Deliberately
  # NOT tenant-scoped: rates are identical across every cluster (see Stripe::WebhookEvent for the
  # same rationale). USD itself is never stored — PricingData short-circuits it to 1.0.
  class ExchangeRate < ApplicationRecord
    validates :currency, presence: true, uniqueness: true
    validates :rate, presence: true
    validates :fetched_at, presence: true
  end
end

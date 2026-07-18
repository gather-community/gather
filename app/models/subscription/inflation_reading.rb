# frozen_string_literal: true

# == Schema Information
#
# Table name: subscription_inflation_readings
#
#  id          :bigint           not null, primary key
#  year        :integer          not null
#  index_value :decimal(12, 4)   not null
#  fetched_at  :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
module Subscription
  # Cached annual US CPI-U index value for a given year. The inflation factor applied to the 2020
  # tier anchors is index(current) / index(2020), so we store raw index values (auditable and
  # recomputable) rather than a precomputed factor. Refreshed nightly by RefreshPricingDataJob,
  # with a synchronous fetch fallback via PricingDataFetcher. Deliberately NOT tenant-scoped:
  # CPI is identical across every cluster (see Stripe::WebhookEvent for the same rationale).
  class InflationReading < ApplicationRecord
    validates :year, presence: true, uniqueness: true
    validates :index_value, presence: true
    validates :fetched_at, presence: true
  end
end

# frozen_string_literal: true

module Subscription
  # Models a subscription of Gather product itself.
  class Subscription < ApplicationRecord
    # Override suffix
    self.table_name = "subscriptions"

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :subscription

    delegate :name, to: :community, prefix: true

    STUB_FIELDS = %i[
      contact_email
      price_per_user_cents
      quantity
      currency
      months_per_period
      start_date
      address_city
      address_country
      address_line1
      address_line2
      address_postal_code
      address_state
    ].freeze

    def empty?
      stripe_id.nil? && quantity.nil?
    end

    def registered?
      stripe_id.present?
    end

    def update_to_registered!(stripe_id)
      self.stripe_id = stripe_id
      STUB_FIELDS.each { |f| self[f] = nil }
      save!
    end
  end
end
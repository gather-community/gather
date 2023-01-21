# frozen_string_literal: true

module Subscription
  # Models a subscription of Gather product itself.
  class Subscription < ApplicationRecord
    # Override suffix
    self.table_name = "subscriptions"

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :subscription

    def empty?
      stripe_id.nil? && quantity.nil?
    end

    def registered?
      stripe_id.present?
    end
  end
end
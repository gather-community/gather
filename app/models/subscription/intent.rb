# frozen_string_literal: true

module Subscription
  # Models a subscription of Gather product itself.
  class Intent < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :subscription_intent

    delegate :name, to: :community, prefix: true

    def registered?
      false
    end

    def incomplete?
      false
    end

    def total_per_invoice
      quantity * price_per_user_cents * months_per_period * (1 - ((discount_percent || 0) / 100))
    end

    def future?
      start_date.present? && start_date > Time.zone.today
    end

    def backdated?
      start_date.present? && start_date < Time.zone.today
    end

    def start_date_to_timestamp
      start_date.present? ? Time.zone.parse(start_date.to_s).to_i : nil
    end
  end
end

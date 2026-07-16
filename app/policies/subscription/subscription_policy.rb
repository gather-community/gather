# frozen_string_literal: true

module Subscription
  class SubscriptionPolicy < ApplicationPolicy
    alias subscription record

    # What the self-serve signup form accepts. Address fields are written by the Stripe Address
    # Element into hidden inputs; the price is never accepted from the client — it's computed
    # server-side from (tier, currency, period).
    def self.permitted_attributes
      %i[tier months_per_period quantity contact_email
        address_line1 address_line2 address_city address_state address_postal_code address_country]
    end

    delegate :permitted_attributes, to: :class

    def show?
      active_admin_or?(:biller)
    end

    def new?
      active_admin_or?(:biller)
    end

    def create?
      active_admin_or?(:biller)
    end

    def start_payment?
      active_admin_or?(:biller)
    end

    def payment?
      active_admin_or?(:biller)
    end

    def success?
      active_admin_or?(:biller)
    end

    def update_messaging_topup?
      active_admin_or?(:biller)
    end
  end
end

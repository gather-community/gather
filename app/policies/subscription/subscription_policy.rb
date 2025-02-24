# frozen_string_literal: true

module Subscription
  class SubscriptionPolicy < ApplicationPolicy
    alias subscription record

    def show?
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
  end
end

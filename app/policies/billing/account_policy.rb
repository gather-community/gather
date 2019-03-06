# frozen_string_literal: true

module Billing
  class AccountPolicy < BillingPolicy
    alias account record

    def index?
      active_admin_or?(:biller)
    end

    def yours?
      true
    end

    def apply_late_fees?
      active_admin_or?(:biller)
    end

    def show?
      active_admin_or?(:biller) || account_owner?
    end

    def add_txn?
      active_admin_or?(:biller)
    end

    def update?
      active_admin_or?(:biller)
    end

    def permitted_attributes
      [:credit_limit]
    end
  end
end

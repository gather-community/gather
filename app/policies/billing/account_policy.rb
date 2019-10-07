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

    def exportable_attributes
      %i[number household_id household_name balance_due current_balance credit_limit
         last_statement_id last_statement_on due_last_statement total_new_charges
         total_new_credits created_at]
    end
  end
end

module Billing
  class AccountPolicy < BillingPolicy
    alias_method :account, :record

    def index?
      active_admin_or_biller?
    end

    def show?
      active_admin_or_biller? || account_owner?
    end

    def update?
      active_admin_or_biller?
    end

    def apply_late_fees?
      active_admin_or_biller?
    end

    def permitted_attributes
      [:credit_limit]
    end
  end
end

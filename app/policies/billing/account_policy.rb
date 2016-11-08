module Billing
  class AccountPolicy < BillingPolicy
    alias_method :account, :record

    def index?
      admin_or_biller?
    end

    def show?
      admin_or_biller? || account_owner?
    end

    def update?
      admin_or_biller?
    end

    def apply_late_fees?
      admin_or_biller?
    end

    def permitted_attributes
      [:credit_limit]
    end
  end
end

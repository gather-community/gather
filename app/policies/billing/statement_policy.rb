module Billing
  class StatementPolicy < BillingPolicy
    alias_method :statement, :record

    def index?
      active_admin_or_biller?
    end

    def generate?
      active_admin_or_biller?
    end

    def show?
      active_admin_or_biller? || account_owner?
    end

    protected

    def allow_class_based_auth?
      false
    end
  end
end

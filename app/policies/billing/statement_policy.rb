module Billing
  class StatementPolicy < BillingPolicy
    alias_method :statement, :record

    def index?
      admin_or_biller?
    end

    def generate?
      admin_or_biller?
    end

    def show?
      admin_or_biller? || account_owner?
    end
  end
end

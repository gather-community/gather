# frozen_string_literal: true

module Billing
  class TransactionPolicy < BillingPolicy
    alias transaction record

    def index?
      true
    end

    def show?
      false # Not used presently
    end

    def create?
      active_admin_or?(:biller)
    end

    def permitted_attributes
      %i[incurred_on code description amount]
    end
  end
end

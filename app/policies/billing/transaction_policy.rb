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

    def exportable_attributes
      %i[id incurred_on code chg_crd description quantity unit_price amount created_at
         account_id statement_id meal_id]
    end
  end
end

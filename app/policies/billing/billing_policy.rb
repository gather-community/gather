# frozen_string_literal: true

module Billing
  class BillingPolicy < ApplicationPolicy
    class Scope < Scope
      def resolve
        if active_admin_or?(:biller)
          scope.for_community_or_household(user.community, user.household)
        else
          scope.for_household(user.household)
        end
      end
    end

    private

    def account_owner?
      user.household == record.household
    end
  end
end

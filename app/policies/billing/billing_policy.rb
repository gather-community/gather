module Billing
  class BillingPolicy < ApplicationPolicy
    class Scope < ApplicationPolicy::Scope
      def resolve
        if admin_or_biller?
          scope.for_community_or_household(user.community, user.household)
        else
          scope.for_household(user.household)
        end
      end
    end

    private

    def same_community_admin_or_biller?
      admin_or_biller? && user.community == record.community
    end

    def account_owner?
      user.household == record.household
    end
  end
end


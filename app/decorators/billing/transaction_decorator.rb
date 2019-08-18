module Billing
  class TransactionDecorator < ApplicationDecorator
    delegate_all

    def household_name
      account.decorate.household_name
    end

    def statementable_path
      if statementable.is_a?(Meals::Meal)
        h.meal_path(statementable)
      end
    end
  end
end

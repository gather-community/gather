# frozen_string_literal: true

module Billing
  class TransactionDecorator < ApplicationDecorator
    include TransactableDecorable

    delegate_all

    def household_name
      account.decorate.household_name
    end

    def statementable_path
      h.meal_url(statementable) if statementable.is_a?(Meals::Meal)
    end
  end
end

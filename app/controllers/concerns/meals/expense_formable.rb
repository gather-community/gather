# frozen_string_literal: true

module Meals
  # Methods common to controllers that can render the meal expense form
  module ExpenseFormable
    extend ActiveSupport::Concern

    def prep_expense_form_vars
      cook = @meal.head_cook
      @meal.build_cost(reimbursee: cook) if @meal.cost.nil?
      @paypal_email = @meal.cost.reimbursee&.paypal_email_or_default
    end
  end
end

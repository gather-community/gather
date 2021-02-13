# frozen_string_literal: true

class AddReimburseeToMealCosts < ActiveRecord::Migration[6.0]
  def change
    add_reference :meal_costs, :reimbursee, foreign_key: {to_table: :users}, index: true
  end
end

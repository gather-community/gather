# frozen_string_literal: true

class RenameMealCostTable < ActiveRecord::Migration[4.2]
  def change
    rename_table :meal_costs, :meals_costs
  end
end

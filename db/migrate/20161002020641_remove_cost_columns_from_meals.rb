# frozen_string_literal: true

class RemoveCostColumnsFromMeals < ActiveRecord::Migration[4.2]
  def up
    remove_column :meals, :ingredient_cost
    remove_column :meals, :pantry_cost
  end
end

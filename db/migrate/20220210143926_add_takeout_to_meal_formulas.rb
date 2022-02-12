# frozen_string_literal: true

class AddTakeoutToMealFormulas < ActiveRecord::Migration[6.0]
  def change
    add_column :meal_formulas, :takeout, :boolean, default: false, null: false
  end
end

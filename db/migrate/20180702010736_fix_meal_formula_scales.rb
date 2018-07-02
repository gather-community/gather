# frozen_string_literal: true

class FixMealFormulaScales < ActiveRecord::Migration[5.1]
  def up
    change_column :meal_formulas, :adult_meat, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :adult_veg, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :big_kid_meat, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :big_kid_veg, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :little_kid_meat, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :little_kid_veg, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :pantry_fee, :decimal, precision: 10, scale: 4, null: false
    change_column :meal_formulas, :senior_meat, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :senior_veg, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :teen_meat, :decimal, precision: 10, scale: 4
    change_column :meal_formulas, :teen_veg, :decimal, precision: 10, scale: 4
  end
end

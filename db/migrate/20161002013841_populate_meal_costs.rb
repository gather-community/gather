# frozen_string_literal: true

class Meals::Cost < ApplicationRecord
  self.table_name = "meal_costs"
  belongs_to :meal, inverse_of: :cost
end

class PopulateMealCosts < ActiveRecord::Migration[4.2]
  def up
    transaction do
      Meal.where(status: "finalized").find_each do |meal|
        mcost = meal.build_cost(meal: meal)
        mcost.pantry_cost = meal.read_attribute(:pantry_cost)
        mcost.ingredient_cost = meal.read_attribute(:ingredient_cost)
        calculator = Meals::CostCalculator.build(meal)
        Signup::SIGNUP_TYPES.each do |st|
          mcost[st] = calculator.price_for(st)
        end
        mcost.meal_calc_type = calculator.meal_calc_type
        mcost.pantry_calc_type = calculator.pantry_calc_type
        mcost.pantry_fee = calculator.pantry_fee
        mcost.save!
      end
    end
  end
end

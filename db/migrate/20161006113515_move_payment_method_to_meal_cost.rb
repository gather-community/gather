class MovePaymentMethodToMealCost < ActiveRecord::Migration
  def up
    add_column :meal_costs, :payment_method, :string
    MealCost.all.each { |mc| mc.update_attribute(:payment_method, mc.meal.payment_method) }
    change_column_null :meal_costs, :payment_method, false
    change_column_null :meal_costs, :pantry_cost, false
    change_column_null :meal_costs, :ingredient_cost, false
  end
end

class Meals::Cost < ActiveRecord::Base
  self.table_name = "meal_costs"
  belongs_to :meal, inverse_of: :cost
end

class MovePaymentMethodToMealCost < ActiveRecord::Migration
  def up
    transaction do
      add_column :meal_costs, :payment_method, :string
      Meals::Cost.all.each { |mc| mc.update_attribute(:payment_method, mc.meal.payment_method) }
      change_column_null :meal_costs, :payment_method, false
      change_column_null :meal_costs, :pantry_cost, false
      change_column_null :meal_costs, :ingredient_cost, false
    end
  end
end

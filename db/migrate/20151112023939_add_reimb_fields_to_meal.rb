class AddReimbFieldsToMeal < ActiveRecord::Migration
  def change
    add_column :meals, :ingredient_cost, :decimal, precision: 10, scale: 3
    add_column :meals, :pantry_cost, :decimal, precision: 10, scale: 3
    add_column :meals, :payment_method, :string
  end
end

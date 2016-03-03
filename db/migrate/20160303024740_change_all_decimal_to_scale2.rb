class ChangeAllDecimalToScale2 < ActiveRecord::Migration
  def up
    change_column :accounts, :balance_due, :decimal, precision: 10, scale: 2
    change_column :accounts, :current_balance, :decimal, precision: 10, scale: 2
    change_column :formulas, :adult_meat, :decimal, precision: 10, scale: 2
    change_column :formulas, :adult_veg, :decimal, precision: 10, scale: 2
    change_column :formulas, :big_kid_meat, :decimal, precision: 10, scale: 2
    change_column :formulas, :big_kid_veg, :decimal, precision: 10, scale: 2
    change_column :formulas, :little_kid_meat, :decimal, precision: 10, scale: 2
    change_column :formulas, :little_kid_veg, :decimal, precision: 10, scale: 2
    change_column :formulas, :pantry_fee, :decimal, precision: 10, scale: 2
    change_column :formulas, :senior_meat, :decimal, precision: 10, scale: 2
    change_column :formulas, :senior_veg, :decimal, precision: 10, scale: 2
    change_column :formulas, :teen_meat, :decimal, precision: 10, scale: 2
    change_column :formulas, :teen_veg, :decimal, precision: 10, scale: 2
    change_column :meals, :ingredient_cost, :decimal, precision: 10, scale: 2
    change_column :meals, :pantry_cost, :decimal, precision: 10, scale: 2
    change_column :statements, :prev_balance, :decimal, precision: 10, scale: 2
    change_column :statements, :total_due, :decimal, precision: 10, scale: 2
    change_column :transactions, :amount, :decimal, precision: 10, scale: 2
    change_column :transactions, :unit_price, :decimal, precision: 10, scale: 2
  end
end

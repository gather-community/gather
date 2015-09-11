class AddDiscountToMeals < ActiveRecord::Migration
  def change
    add_column :meals, :discount, :decimal, null: false, default: 0, precision: 5, scale: 2
  end
end

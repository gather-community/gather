# frozen_string_literal: true

class AddDiscountToMeals < ActiveRecord::Migration[4.2]
  def change
    add_column :meals, :discount, :decimal, null: false, default: 0, precision: 5, scale: 2
  end
end

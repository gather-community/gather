# frozen_string_literal: true

class RemoveDiscountedFromMealTypes < ActiveRecord::Migration[5.1]
  def up
    remove_column :meal_types, :discounted
  end
end

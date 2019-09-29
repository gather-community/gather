# frozen_string_literal: true

class AddDeactivatedAtToMealTypes < ActiveRecord::Migration[5.1]
  def change
    add_column :meal_types, :deactivated_at, :datetime
  end
end

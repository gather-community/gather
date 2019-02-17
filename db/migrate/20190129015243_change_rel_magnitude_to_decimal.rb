# frozen_string_literal: true

class ChangeRelMagnitudeToDecimal < ActiveRecord::Migration[5.1]
  def change
    change_column :meal_role_reminders, :rel_magnitude, :decimal, precision: 10, scale: 2
    change_column :work_reminders, :rel_magnitude, :decimal, precision: 10, scale: 2
  end
end

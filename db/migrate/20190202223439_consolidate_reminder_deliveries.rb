# frozen_string_literal: true

class ConsolidateReminderDeliveries < ActiveRecord::Migration[5.1]
  def change
    add_reference :work_reminder_deliveries, :meal, foreign_key: true, index: true
    add_index :work_reminder_deliveries, %i[reminder_id meal_id], unique: true
    rename_table :work_reminder_deliveries, :reminder_deliveries

    # Add check constraint to require exactly one of meal_id or shift_id.
    add_check_constraint :reminder_deliveries,
                         "(shift_id IS NOT NULL AND meal_id is NULL) OR (meal_id IS NOT NULL AND shift_id is NULL)"
  end
end

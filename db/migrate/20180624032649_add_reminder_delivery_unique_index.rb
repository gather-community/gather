# frozen_string_literal: true

class AddReminderDeliveryUniqueIndex < ActiveRecord::Migration[5.1]
  def change
    add_index :work_reminder_deliveries, [:reminder_id, :shift_id], unique: true
  end
end

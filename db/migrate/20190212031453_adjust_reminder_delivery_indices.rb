# frozen_string_literal: true

class AdjustReminderDeliveryIndices < ActiveRecord::Migration[5.1]
  def change
    remove_index :reminder_deliveries, name: "index_reminder_deliveries_on_reminder_id_and_meal_id"
    remove_index :reminder_deliveries, name: "index_reminder_deliveries_on_reminder_id_and_shift_id"
    add_index :reminder_deliveries, "shift_id"
    add_index :reminder_deliveries, "reminder_id"
  end
end

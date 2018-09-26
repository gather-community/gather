# frozen_string_literal: true

# Boolean flag
class AddDeliveredToWorkReminderDeliveries < ActiveRecord::Migration[5.1]
  def change
    add_column :work_reminder_deliveries, :delivered, :boolean, null: false, default: false
  end
end

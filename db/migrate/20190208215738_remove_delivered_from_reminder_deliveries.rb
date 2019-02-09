# frozen_string_literal: true

class RemoveDeliveredFromReminderDeliveries < ActiveRecord::Migration[5.1]
  def up
    execute("DELETE FROM reminder_deliveries WHERE delivered = 't'")
    remove_column :reminder_deliveries, :delivered
  end
end

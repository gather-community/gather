# frozen_string_literal: true

class AddTypeToReminderDeliveries < ActiveRecord::Migration[5.1]
  def up
    add_column :reminder_deliveries, :type, :string
    execute("UPDATE reminder_deliveries SET type = 'Work::JobReminderDelivery'")
  end
end

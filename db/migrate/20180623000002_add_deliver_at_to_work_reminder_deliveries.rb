# frozen_string_literal: true

class AddDeliverAtToWorkReminderDeliveries < ActiveRecord::Migration[5.1]
  def change
    add_column :work_reminder_deliveries, :deliver_at, :datetime, null: false
    add_index :work_reminder_deliveries, :deliver_at
    remove_index :work_reminder_deliveries, name: :index_work_reminder_deliveries_on_fks
  end
end

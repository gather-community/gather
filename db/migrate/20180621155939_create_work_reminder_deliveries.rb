# frozen_string_literal: true

class CreateWorkReminderDeliveries < ActiveRecord::Migration[5.1]
  def change
    create_table :work_reminder_deliveries do |t|
      t.integer :reminder_id, null: false
      t.integer :shift_id, null: false
      t.integer :cluster_id, null: false

      t.timestamps
    end
    add_index :work_reminder_deliveries, %i[cluster_id reminder_id shift_id],
      unique: true, name: "index_work_reminder_deliveries_on_fks"
    add_foreign_key :work_reminder_deliveries, :work_reminders, column: :reminder_id
    add_foreign_key :work_reminder_deliveries, :work_shifts, column: :shift_id
    add_foreign_key :work_reminder_deliveries, :clusters
  end
end

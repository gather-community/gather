# frozen_string_literal: true

class CreateMealReminderDeliveries < ActiveRecord::Migration[5.1]
  def change
    create_table :meal_reminder_deliveries do |t|
      t.integer "cluster_id", null: false
      t.datetime "deliver_at", null: false
      t.boolean "delivered", default: false, null: false
      t.integer "reminder_id", null: false
      t.integer "assignment_id", null: false
      t.timestamps
      t.index %w[reminder_id assignment_id],
        name: "index_meal_reminder_deliveries_on_reminder_id_and_assignment_id", unique: true
      t.index ["deliver_at"], name: "index_meal_reminder_deliveries_on_deliver_at"
    end
    add_foreign_key :meal_reminder_deliveries, :meal_role_reminders, column: :reminder_id
    add_foreign_key :meal_reminder_deliveries, :meal_assignments, column: :assignment_id
    add_foreign_key :meal_reminder_deliveries, :clusters
  end
end

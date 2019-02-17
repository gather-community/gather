# frozen_string_literal: true

class RemoveWorkRemindersForeignKey < ActiveRecord::Migration[5.1]
  def change
    remove_foreign_key "reminder_deliveries", "work_reminders"
  end
end

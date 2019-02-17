# frozen_string_literal: true

class ReAddReminderIdForeignKey < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :reminder_deliveries, :reminders
  end
end

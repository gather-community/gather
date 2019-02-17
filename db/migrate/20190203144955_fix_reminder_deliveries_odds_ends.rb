# frozen_string_literal: true

class FixReminderDeliveriesOddsEnds < ActiveRecord::Migration[5.1]
  def change
    change_column_null :reminder_deliveries, :type, false
    drop_table :meal_reminder_deliveries
  end
end

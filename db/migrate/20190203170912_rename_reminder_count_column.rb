# frozen_string_literal: true

class RenameReminderCountColumn < ActiveRecord::Migration[5.1]
  def change
    rename_column :meal_assignments, :reminder_count, :cook_menu_reminder_count
  end
end

# frozen_string_literal: true

# Shuffle column setup for relative time
class RenameReminderColumns < ActiveRecord::Migration[5.1]
  def up
    rename_column :work_reminders, :rel_time, :rel_magnitude
    rename_column :work_reminders, :time_unit, :rel_unit_sign
    execute("UPDATE work_reminders SET
        rel_magnitude = @ rel_magnitude,
        rel_unit_sign = rel_unit_sign || '_' || CASE WHEN rel_magnitude < 0 THEN 'before' ELSE 'after' END
      WHERE rel_magnitude IS NOT NULL")
  end
end

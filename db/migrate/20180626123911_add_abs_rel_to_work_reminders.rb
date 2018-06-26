# frozen_string_literal: true

# New enum column.
class AddAbsRelToWorkReminders < ActiveRecord::Migration[5.1]
  def up
    add_column :work_reminders, :abs_rel, :string
    execute("UPDATE work_reminders SET abs_rel = 'relative'")
    change_column_null :work_reminders, :abs_rel, false
  end
end

# frozen_string_literal: true

class UnifyReminderTables < ActiveRecord::Migration[5.1]
  def up
    rename_table :work_reminders, :reminders
    change_column_null :reminders, :job_id, true
    change_column :reminders, :job_id, :bigint
    add_reference :reminders, :role, index: true, foreign_key: {to_table: :meal_roles}
    add_column :reminders, :type, :string
    execute("UPDATE reminders SET type = 'Work::JobReminder'")
    change_column_null :reminders, :type, false
    drop_table :meal_role_reminders

    # Add check constraint to require exactly one of role_id or job_id.
    add_check_constraint :reminders,
                         "(role_id IS NOT NULL AND job_id is NULL) OR (job_id IS NOT NULL AND role_id is NULL)", name: :reminders_job_role
  end
end

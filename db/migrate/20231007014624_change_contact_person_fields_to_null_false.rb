# frozen_string_literal: true

class ChangeContactPersonFieldsToNullFalse < ActiveRecord::Migration[7.0]
  def up
    execute("UPDATE gdrive_migration_operations SET contact_name = 'Foo Bar', " \
            "contact_email = 'foo@example.com' WHERE contact_name IS NULL")
    change_column_null :gdrive_migration_operations, :contact_name, false
    change_column_null :gdrive_migration_operations, :contact_email, false
  end

  def down
    change_column_null :gdrive_migration_operations, :contact_name, true
    change_column_null :gdrive_migration_operations, :contact_email, true
  end
end

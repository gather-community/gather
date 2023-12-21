# frozen_string_literal: true

class AddContactPersonToMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :contact_name, :string
    add_column :gdrive_migration_operations, :contact_email, :string
  end
end

# frozen_string_literal: true

class RemoveFieldsFromGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_operations, :cancel_reason, :string
    remove_column :gdrive_migration_operations, :error_count, :integer
    remove_column :gdrive_migration_operations, :scanned_file_count, :integer
  end
end

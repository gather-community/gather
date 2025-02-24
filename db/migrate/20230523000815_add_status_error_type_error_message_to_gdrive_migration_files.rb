# frozen_string_literal: true

class AddStatusErrorTypeErrorMessageToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :status, :string, null: false, index: true
    add_check_constraint :gdrive_migration_files, "status IN ('pending', 'error', 'declined', 'done')",
                         name: :status_enum

    add_column :gdrive_migration_files, :error_type, :string, index: true
    add_check_constraint :gdrive_migration_files, "error_type IN ('forbidden', 'not_found')",
                         name: :error_type_enum

    add_column :gdrive_migration_files, :error_message, :string, limit: 255
  end
end

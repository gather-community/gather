# frozen_string_literal: true

class FixGDriveMigrationFilesForeignKey < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :gdrive_migration_files, :gdrive_configs, column: "operation_id"
    add_foreign_key :gdrive_migration_files, :gdrive_migration_operations, column: "operation_id"
  end
end

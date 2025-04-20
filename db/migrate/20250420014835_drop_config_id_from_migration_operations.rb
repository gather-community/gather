# frozen_string_literal: true

class DropConfigIdFromMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_operations, :config_id, :integer
  end
end

# frozen_string_literal: true

class AddActiveToGDriveMigrationOperations < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_operations, :active, :boolean, default: true, null: false
  end
end

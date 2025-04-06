# frozen_string_literal: true

class AddMigratedParentIdToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_files, :migrated_parent_id, :string
  end
end

# frozen_string_literal: true

class RenameGDriveUnownedFilesToGDriveMigrationFiles < ActiveRecord::Migration[7.0]
  def change
    rename_table :gdrive_unowned_files, :gdrive_migration_files
  end
end

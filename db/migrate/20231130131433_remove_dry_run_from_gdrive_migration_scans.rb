# frozen_string_literal: true

class RemoveDryRunFromGDriveMigrationScans < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_scans, :dry_run, :boolean, default: false, null: false
  end
end

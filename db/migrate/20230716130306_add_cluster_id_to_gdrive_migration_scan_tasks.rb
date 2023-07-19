# frozen_string_literal: true

class AddClusterIdToGDriveMigrationScanTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_scan_tasks, :cluster_id, :integer, null: false, index: true
  end
end

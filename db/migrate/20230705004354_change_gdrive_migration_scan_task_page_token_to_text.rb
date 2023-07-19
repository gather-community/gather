# frozen_string_literal: true

class ChangeGDriveMigrationScanTaskPageTokenToText < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_scan_tasks, :page_token, :string
    add_column :gdrive_migration_scan_tasks, :page_token, :text
  end
end

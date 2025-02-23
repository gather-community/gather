# frozen_string_literal: true

class CreateGDriveMigrationScanTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_migration_scan_tasks do |t|
      t.references :operation, foreign_key: {to_table: :gdrive_migration_operations},
                               null: false, index: true
      t.string :folder_id, null: false, limit: 128
      t.string :page_token, limit: 128

      t.timestamps
    end
  end
end

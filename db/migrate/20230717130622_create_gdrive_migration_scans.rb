# frozen_string_literal: true

class CreateGDriveMigrationScans < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_migration_scans do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :operation, foreign_key: {to_table: :gdrive_migration_operations}, index: true,
                               null: false
      t.string :status, limit: 32, default: "new", null: false
      t.string :scope, limit: 16, default: "full", null: false
      t.integer :error_count, default: 0, null: false
      t.string :cancel_reason, limit: 128
      t.integer :scanned_file_count, default: 0, null: false

      t.timestamps
    end
  end
end

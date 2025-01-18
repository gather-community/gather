# frozen_string_literal: true

class CreateGDriveMigrationLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_migration_logs do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :operation, index: true, null: false, foreign_key: {to_table: :gdrive_migration_operations}
      t.string :level, null: false
      t.text :message, null: false
      t.jsonb :data
      t.datetime :created_at, null: false, index: true
    end
  end
end

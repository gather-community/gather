# frozen_string_literal: true

class RemoveIngestColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :gdrive_migration_requests, :ingest_file_ids, :jsonb
    remove_column :gdrive_migration_requests, :ingest_progress, :integer
    remove_column :gdrive_migration_requests, :ingest_requested_at, :datetime
    remove_column :gdrive_migration_requests, :ingest_status, :string
    remove_column :gdrive_migration_requests, :temp_drive_id, :string
  end
end

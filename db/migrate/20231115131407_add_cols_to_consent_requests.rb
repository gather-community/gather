# frozen_string_literal: true

class AddColsToConsentRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_consent_requests, :ingest_requested_at, :datetime
    add_column :gdrive_migration_consent_requests, :ingest_file_ids, :jsonb
    add_column :gdrive_migration_consent_requests, :ingest_status, :string
  end
end

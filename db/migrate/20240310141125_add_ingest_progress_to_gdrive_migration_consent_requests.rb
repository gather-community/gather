# frozen_string_literal: true

class AddIngestProgressToGDriveMigrationConsentRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_consent_requests, :ingest_progress, :integer
  end
end

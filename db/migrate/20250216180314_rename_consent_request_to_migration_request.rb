# frozen_string_literal: true

class RenameConsentRequestToMigrationRequest < ActiveRecord::Migration[7.0]
  def change
    rename_table :gdrive_migration_consent_requests, :gdrive_migration_requests
  end
end

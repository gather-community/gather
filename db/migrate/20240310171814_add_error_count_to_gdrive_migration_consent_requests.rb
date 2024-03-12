# frozen_string_literal: true

class AddErrorCountToGDriveMigrationConsentRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_consent_requests, :error_count, :integer, null: false, default: 0
  end
end

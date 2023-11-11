# frozen_string_literal: true

class AddTokenToGDriveMigrationConsentRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_consent_requests, :token, :string, null: false
  end
end

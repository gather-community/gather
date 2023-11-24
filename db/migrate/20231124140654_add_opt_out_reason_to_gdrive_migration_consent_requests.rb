# frozen_string_literal: true

class AddOptOutReasonToGDriveMigrationConsentRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_consent_requests, :opt_out_reason, :text, limit: 2048
  end
end

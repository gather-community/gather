class AddTempDriveIdToGDriveMigrationConsentRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_migration_consent_requests, :temp_drive_id, :string
  end
end

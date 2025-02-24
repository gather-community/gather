# frozen_string_literal: true

class CreateGDriveMigrationConsentRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_migration_consent_requests do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :operation, index: true, null: false,
                               foreign_key: {to_table: :gdrive_migration_operations}
      t.string :google_email, null: false, limit: 255
      t.integer :file_count, null: false
      t.string :status, null: false, limit: 16

      t.timestamps
    end
  end
end

# frozen_string_literal: true

class CreateGDriveSyncedPermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :gdrive_synced_permissions do |t|
      t.references :cluster, null: false, index: true, foreign_key: true
      t.integer :user_id,
                index: true,
                null: false,
                comment: "Deliberately not a foreign key because we want to retain ID information even after user " \
                         "record destroyed so we can search by ID in PermissionSyncJob."
      t.integer :item_id,
                index: true,
                null: false,
                comment: "Deliberately not a foreign key because we want to retain ID information even after item " \
                         "record destroyed so we can search by ID in PermissionSyncJob."
      t.string :item_external_id, null: false, limit: 128
      t.string :google_email, null: false, limit: 256
      t.string :access_level, null: false, limit: 32

      t.timestamps
    end
  end
end

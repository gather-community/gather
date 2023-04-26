# frozen_string_literal: true

class AddExternalIdToGDriveSyncedPermissions < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_synced_permissions, :external_id, :string, null: false, unique: true
  end
end

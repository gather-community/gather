# frozen_string_literal: true

class AddInheritedAccessLevelToGDriveSyncedPermissions < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_synced_permissions, :inherited_access_level, :string, limit: 32
  end
end

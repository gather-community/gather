# frozen_string_literal: true

# Refreshing synced permissions reads users' actual roles from Google Drive, which may include
# roles Gather never grants (shared drive Manager, owner). Allow storing them so they act as a floor.
# gdrive_item_groups keeps the narrower constraint since Gather doesn't grant these.
class AllowUnmanagedLevelsOnGDriveSyncedPermissions < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :gdrive_synced_permissions,
      "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer')", name: :access_level_enum
    add_check_constraint :gdrive_synced_permissions,
      "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer', 'organizer', 'owner')",
      name: :access_level_enum
  end
end

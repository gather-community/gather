# frozen_string_literal: true

module GDrive
  # Syncs permissions for a given User from Gather to Google Drive.
  # Keeps track of permissions in the GDrive::SyncedPermission model.
  class UserPermissionSyncJob < ApplicationJob
  end
end

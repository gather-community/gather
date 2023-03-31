# frozen_string_literal: true

module GDrive
  # Syncs permissions from Gather to Google Drive.
  # Keeps track of permissions in the GDrive::SyncedPermission model.
  class PermissionSyncJob < ApplicationJob
  end
end

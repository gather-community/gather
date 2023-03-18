# frozen_string_literal: true

module GDrive
  # Syncs permission data with Google Drive.
  class SyncListener
    include Singleton

    attr_accessor :last_method_txn_ids

    def create_user_successful(user)
      item_groups = ItemGroup.where(group: Groups::Group.with_user(user).select(:id)).includes(:item)
      permissions = item_groups.map do |item_group|
        {
          google_email: user.google_email,
          item_id: item_group.item_external_id,
          access_level: item_group.access_level
        }
      end
      PermissionSyncJob.perform_later(permissions) unless permissions.empty?
    end
  end
end

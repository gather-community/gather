# frozen_string_literal: true

module GDrive
  # Syncs permissions for a given User from Gather to Google Drive.
  # Keeps track of permissions in the GDrive::SyncedPermission model.
  class UserPermissionSyncJob < PermissionSyncJob
    def perform(cluster_id:, community_id:, user_id:)
      with_cluster_and_api_wrapper(cluster_id: cluster_id, community_id: community_id) do
        self.user_id = user_id

        # We shouldn't allow any Item syncs to happen while a User sync is running
        # b/c it could result in a race condition.
        # But this can be a shared lock when held during a User sync
        # b/c we don't care if other User syncs are running.
        lock_name = "gdrive-permission-sync-all-items"
        User.with_advisory_lock!(lock_name, shared: true, timeout_seconds: 120, disable_query_cache: true) do
          lock_name = "gdrive-permission-sync-user-#{user_id}"
          Item.with_advisory_lock!(lock_name, timeout_seconds: 120, disable_query_cache: true) do
            handle_user_with_lock(user_id)
          end
        end
      end
    end

    private

    attr_accessor :user_id, :user, :permissions_by_item_id

    def handle_user_with_lock(user_id)
      # Use find_by because the user may not exist anymore.
      self.user = User.find_by(id: user_id)

      # Make a hash by item_id of all existing SyncedPermissions
      self.permissions_by_item_id = GDrive::SyncedPermission.where(user_id: user_id).index_by(&:item_id)

      # Clear the access level. If it's still nil at the end of this method, we should delete
      # the permission.
      permissions_by_item_id.values.each { |p| p.access_level = nil }

      # User may have been deleted between when the job was enqueued and when it was run.
      if user.present? && user.active? && user.google_email.present?
        group_ids = Groups::Group.with_user(user).active.pluck(:id)
        ItemGroup.where(group_id: group_ids).each do |item_group|
          process_permissions_for_item_group(item_group)
        end
      end

      # We sort by persisted b/c we want to ensure we delete before we create.
      # We sort by item external ID test purposes, so that the order of the permissions is consistent,
      # so that the order of requests is also consistent in order to match the cassette.
      permissions_by_item_id.values.sort_by { |p| [p.persisted? ? 0 : 1, p.item_external_id] }.each do |perm|
        apply_permission_changes(perm)
      end
    end

    def process_permissions_for_item_group(item_group)
      permission = permissions_by_item_id[item_group.item_id]
      if permission.present?
        permission.google_email = user.google_email
        if access_level_cmp(item_group.access_level, permission.access_level) == 1
          permission.access_level = item_group.access_level
        end
      else
        permissions_by_item_id[user.id] = build_synced_permission(user, item_group.item,
          item_group.access_level)
      end
    end
  end
end

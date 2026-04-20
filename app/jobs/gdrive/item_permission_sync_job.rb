# frozen_string_literal: true

module GDrive
  # Syncs permissions for a given Item from Gather to Google Drive.
  # Keeps track of permissions in the GDrive::SyncedPermission model.
  class ItemPermissionSyncJob < PermissionSyncJob
    def perform(cluster_id:, community_id:, item_id:, refresh_synced_permissions: false)
      if refresh_synced_permissions
        Rails.logger.info("Refreshing synced permissions before item sync", item_id: item_id)
        RefreshSyncedPermissionsJob.perform_now(cluster_id: cluster_id, community_id: community_id,
          item_id: item_id)
      end

      with_cluster_and_api_wrapper(cluster_id: cluster_id, community_id: community_id) do
        self.item_id = item_id

        # We shouldn't allow any User syncs to happen while an Item sync is running
        # b/c it could result in a race condition, e.g. if a User's google_email changes
        # while an Item sync is running, that could get real messy. Best to wait until
        # all Item syncs are done before running the User sync.
        # But this can be a shared lock when held during an Item sync
        # b/c we don't care if other Item syncs are running.
        # We also don't care what happens in other communities since they have their own GDrive config.
        lock_name = "gdrive-permission-sync-all-users-cmty-#{community_id}"
        User.with_advisory_lock!(lock_name, shared: true, timeout_seconds: 120, disable_query_cache: true) do
          lock_name = "gdrive-permission-sync-item-#{item_id}"
          Item.with_advisory_lock!(lock_name, timeout_seconds: 120, disable_query_cache: true) do
            handle_item_with_lock(item_id)
          end
        end
      end
    end

    private

    attr_accessor :item_id, :item, :permissions_by_user_id

    def handle_item_with_lock(item_id)
      # Use find_by because the item may not exist anymore.
      self.item = Item.find_by(id: item_id)

      # Make a hash by user_id of all existing SyncedPermissions
      self.permissions_by_user_id = GDrive::SyncedPermission.where(item_id: item_id).index_by(&:user_id)

      # Reset access_level to inherited_access_level (which may be nil). If it remains nil after
      # processing all ItemGroups, the permission should be deleted.
      permissions_by_user_id.values.each { |p| p.access_level = p.inherited_access_level }

      # If the item has been destroyed, there can't be any ItemGroups for it
      # since they are linked by a foreign key. So this loop will be a no-op.
      ItemGroup.where(item_id: item_id).each do |item_group|
        process_permissions_for_item_group(item_group)
      end

      # We sort by persisted b/c we want to ensure we delete before we create.
      # We sort by google_email for test purposes, so that the order of the permissions is consistent,
      # so that the order of requests is also consistent in order to match the cassette.
      permissions_by_user_id.values.sort_by { |p| [p.persisted? ? 0 : 1, p.google_email] }.each do |perm|
        apply_permission_changes(perm)
      end
    end

    def process_permissions_for_item_group(item_group)
      return if item_group.group.deactivated_at.present?

      item_group.group.members.each do |user|
        next if user.deactivated_at.present?
        next if user.google_email.blank?

        permission = permissions_by_user_id[user.id]
        if permission.present?
          Rails.logger.info("Existing permission", user_id: user.id, item_external_id: item_group.item.external_id,
            permission_id: permission.external_id, access_level: permission.access_level)
          permission.google_email = user.google_email
          if access_level_cmp(item_group.access_level, permission.access_level) == 1
            Rails.logger.info("Setting higher access level", new_access_level: item_group.access_level)
            permission.access_level = item_group.access_level
          end
        else
          # No existing permission was found so make a new one. It will get saved when permissions are applied.
          Rails.logger.info("No existing permission, building")
          permissions_by_user_id[user.id] = build_synced_permission(user, item, item_group.access_level)
        end
      end
    end
  end
end

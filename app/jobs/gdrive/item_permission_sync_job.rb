# frozen_string_literal: true

module GDrive
  # Syncs permissions for a given Item from Gather to Google Drive.
  # Keeps track of permissions in the GDrive::SyncedPermission model.
  class ItemPermissionSyncJob < ApplicationJob
    def perform(cluster_id:, item_id:)
      self.item_id = item_id

      with_cluster(Cluster.find(cluster_id)) do
        # We shouldn't allow any User syncs to happen while an Item sync is running
        # b/c it could result in a race condition.
        # But this can be a shared lock when held during an Item sync
        # b/c we don't care if other Item syncs are running.
        lock_name = "gdrive-permission-sync-all-users"
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

      # Clear the access level. If it's still nil at the end of this method, we should delete
      # the permission.
      permissions_by_user_id.values.each { |p| p.access_level = nil }

      ItemGroup.where(item_id: item_id).each do |item_group|
        process_permissions_for_item_group(item_group)
      end

      permissions_by_user_id.values.each do |permission|
        permission.access_level.nil? ? permission.destroy : permission.save!
      end
    end

    def process_permissions_for_item_group(item_group)
      return if item_group.group.deactivated_at.present?

      item_group.group.members.each do |user|
        next if user.deactivated_at.present?
        next if user.google_email.blank?

        permission = permissions_by_user_id[user.id]
        if permission.present?
          permission.google_email = user.google_email
          if access_level_cmp(item_group.access_level, permission.access_level) == 1
            permission.access_level = item_group.access_level
          end
        else
          permissions_by_user_id[user.id] = build_synced_permission(user, item_group.access_level)
        end
      end
    end

    def access_level_cmp(level_a, level_b)
      index_a = ItemGroup::ACCESS_LEVELS.index(level_a) || -1
      index_b = ItemGroup::ACCESS_LEVELS.index(level_b) || -1
      index_a <=> index_b
    end

    def build_synced_permission(user, access_level)
      GDrive::SyncedPermission.new(
        item_id: item_id,
        item_external_id: item.external_id,
        user_id: user.id,
        google_email: user.google_email,
        access_level: access_level
      )
    end
  end
end

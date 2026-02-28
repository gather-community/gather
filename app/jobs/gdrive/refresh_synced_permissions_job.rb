# frozen_string_literal: true

module GDrive
  # Refreshes SyncedPermissions for a given item (or all items in a community)
  # by reading current permission data from Google Drive. This populates the
  # inherited_access_level field, which serves as a floor in the permission
  # sync algorithm.
  class RefreshSyncedPermissionsJob < BaseJob
    def perform(cluster_id:, community_id:, item_id: nil)
      with_cluster(Cluster.find(cluster_id)) do
        Rails.logger.info("Refreshing synced permissions",
          community_id: community_id, item_id: item_id || "all")

        community = Community.find(community_id)
        config = Config.find_by!(community_id: community.id)
        self.wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)

        items = item_id ? [Item.find_by(id: item_id)].compact : Item.where(gdrive_config: config)

        # Build a lookup of cluster users by google_email (auto-scoped to current cluster)
        user_id_by_email = User.where.not(google_email: nil).pluck(:google_email, :id).to_h

        Rails.logger.info("Found items to refresh", count: items.size)
        items.each { |item| refresh_item(item, user_id_by_email) }
      end
    end

    private

    attr_accessor :wrapper

    def refresh_item(item, user_id_by_email)
      existing_by_user_id = SyncedPermission.where(item_id: item.id).index_by(&:user_id)
      Rails.logger.info("Refreshing item permissions",
        item_external_id: item.external_id, existing_count: existing_by_user_id.size)

      page_token = nil
      loop do
        Rails.logger.info("Fetching permissions page",
          item_external_id: item.external_id, page_token: page_token || "first")

        result = wrapper.list_permissions(
          item.external_id,
          fields: "permissions(id,emailAddress,role,type,permissionDetails),nextPageToken",
          supports_all_drives: true,
          page_size: 100,
          page_token: page_token
        )

        (result.permissions || []).each do |permission|
          next unless permission.type == "user"

          user_id = user_id_by_email[permission.email_address]
          next unless user_id

          upsert_synced_permission(item, user_id, permission, existing_by_user_id)
        end

        page_token = result.next_page_token
        break if page_token.nil?
      end
    end

    def upsert_synced_permission(item, user_id, permission, existing_by_user_id)
      inherited_level = inherited_access_level_for(permission)

      if (perm = existing_by_user_id[user_id])
        Rails.logger.info("Updating synced permission",
          user_id: user_id, item_external_id: item.external_id,
          inherited_access_level: inherited_level)
        perm.update!(external_id: permission.id, inherited_access_level: inherited_level)
      else
        # Only create a SyncedPermission if the user has a direct (non-inherited) permission.
        # Inherited-only users aren't managed by Gather so don't need a local record.
        direct_level = direct_access_level_for(permission)
        if direct_level.nil?
          Rails.logger.info("Skipping inherited-only permission",
            user_id: user_id, item_external_id: item.external_id, inherited_access_level: inherited_level)
          return
        end

        Rails.logger.info("Creating synced permission",
          user_id: user_id, item_external_id: item.external_id,
          access_level: direct_level, inherited_access_level: inherited_level)
        SyncedPermission.create!(
          item: item,
          item_external_id: item.external_id,
          user_id: user_id,
          google_email: permission.email_address,
          external_id: permission.id,
          access_level: direct_level,
          inherited_access_level: inherited_level
        )
      end
    end

    def inherited_access_level_for(permission)
      return nil if permission.permission_details.blank?

      inherited_roles = permission.permission_details.select(&:inherited).map(&:role)
      return nil if inherited_roles.empty?

      inherited_roles.max_by { |r| ItemGroup::ACCESS_LEVELS.index(r&.to_sym) || -1 }
    end

    def direct_access_level_for(permission)
      # No permissionDetails means this is a direct permission (not a shared drive file)
      return permission.role if permission.permission_details.blank?

      direct_roles = permission.permission_details.reject(&:inherited).map(&:role)
      return nil if direct_roles.empty?

      direct_roles.max_by { |r| ItemGroup::ACCESS_LEVELS.index(r&.to_sym) || -1 }
    end
  end
end

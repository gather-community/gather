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

        items = Item.where(gdrive_config: config).accessible
        items = items.where(id: item_id) if item_id

        # Build a lookup of cluster users by google_email (auto-scoped to current cluster)
        user_id_by_email = User.where.not(google_email: nil).pluck(:google_email, :id).to_h

        Rails.logger.info("Found items to refresh", count: items.size)
        items.each { |item| refresh_item(item, user_id_by_email) }
      end
    end

    private

    attr_accessor :wrapper

    def refresh_item(item, user_id_by_email)
      refresh_item_permissions(item, user_id_by_email)
    rescue Google::Apis::ClientError => error
      raise unless error.message.match?(/notFound: File not found/)
      # The item (e.g. a shared drive) was deleted or the org user lost access. Mark it like
      # ItemSyncer/DriveSyncer do and carry on with the other items.
      Rails.logger.warn("Item not found, marking inaccessible", item_id: item.id,
        item_external_id: item.external_id)
      item.update!(error_type: "inaccessible")
    end

    def refresh_item_permissions(item, user_id_by_email)
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
      inherited_level = GooglePermissionLevels.inherited_level(permission)
      direct_level = GooglePermissionLevels.direct_level(permission)
      existing = existing_by_user_id[user_id]

      # We match Google's permissions to users by their current google_email. If the user's
      # google_email has changed since we recorded their permission, the existing record still points
      # at their old account's permission, and the one we found here belongs to their new account.
      # Repointing the record at the new account would leave the old account's access untracked, so the
      # sync could never remove it. Instead we leave the record alone. The sync then sees the email
      # change, removes the old account's permission and grants the new account.
      if existing && existing.google_email != permission.email_address && existing.external_id != permission.id
        Rails.logger.info("Leaving synced permission for old google_email alone",
          user_id: user_id, item_external_id: item.external_id,
          old_external_id: existing.external_id, new_external_id: permission.id)
        return
      end

      # A direct role Gather doesn't manage (e.g. shared drive Manager) is also a floor, so the sync
      # never downgrades or removes it.
      if SyncedPermission::UNMANAGED_ACCESS_LEVELS.include?(direct_level)
        inherited_level = [inherited_level, direct_level].max_by { |l| SyncedPermission.level_index(l) }
      end

      if existing
        Rails.logger.info("Updating synced permission",
          user_id: user_id, item_external_id: item.external_id,
          inherited_access_level: inherited_level)
        # If the email differs here, it's the same Google account under a new address (the
        # permission ID is the account's ID), so we just record the new address.
        existing.update!(external_id: permission.id, google_email: permission.email_address,
          inherited_access_level: inherited_level)
      else
        # We track inherited-only permissions (no direct level) so that inherited_access_level
        # serves as a floor in the sync algorithm. Without this, a lower-level group grant
        # could cause the sync to attempt a Google API call that would be rejected with
        # cannotModifyInheritedPermission. Use the inherited level as access_level since that
        # reflects the user's actual access on Google Drive.
        access_level = direct_level || inherited_level
        Rails.logger.info("Creating synced permission",
          user_id: user_id, item_external_id: item.external_id,
          access_level: access_level, inherited_access_level: inherited_level,
          inherited_only: direct_level.nil?)
        SyncedPermission.create!(
          item: item,
          item_external_id: item.external_id,
          user_id: user_id,
          google_email: permission.email_address,
          external_id: permission.id,
          access_level: access_level,
          inherited_access_level: inherited_level
        )
      end
    end
  end
end

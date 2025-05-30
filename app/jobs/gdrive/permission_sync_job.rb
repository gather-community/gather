# frozen_string_literal: true

module GDrive
  # Parent class for permission sync jobs.
  class PermissionSyncJob < BaseJob
    protected

    attr_accessor :community, :wrapper

    def with_cluster_and_api_wrapper(cluster_id:, community_id:)
      with_cluster(Cluster.find(cluster_id)) do
        self.community = Community.find(community_id)
        init_api_wrapper
        yield
      end
    end

    def init_api_wrapper
      config = Config.find_by!(community_id: community.id)
      self.wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
    end

    def build_synced_permission(user, item, access_level)
      GDrive::SyncedPermission.new(
        item_id: item.id,
        item_external_id: item.external_id,
        user_id: user.id,
        google_email: user.google_email,
        access_level: access_level
      )
    end

    def access_level_cmp(level_a, level_b)
      index_a = ItemGroup::ACCESS_LEVELS.index(level_a&.to_sym) || -1
      index_b = ItemGroup::ACCESS_LEVELS.index(level_b&.to_sym) || -1
      index_a <=> index_b
    end

    def apply_permission_changes(permission)
      Rails.logger.info("Applying permission changes",
        access_level: permission.access_level,
        google_email: permission.google_email,
        external_id: permission.external_id,
        item_external_id: permission.item_external_id,
        item_id: permission.item_id)
      if permission.access_level.nil?
        Rails.logger.info("Destroying")
        destroy_permission(permission)
      elsif permission.new_record?
        Rails.logger.info("Creating")
        create_permission(permission)
      elsif permission.google_email_changed?
        Rails.logger.info("Destroying and creating (email changed)")
        new_permission = permission.clone_without_external_id
        destroy_permission(permission)
        create_permission(new_permission)
      elsif permission.access_level_changed?
        Rails.logger.info("Updating access level")
        update_permission_access_level(permission)
      end
    rescue Google::Apis::ClientError => error
      if error.message.match?(/notFound: File not found/)
        item = permission.item
        Rails.logger.warn("Item #{item.external_id} was not found. " \
          "Deleting local item #{item.id} and associated records")
        item.destroy
        permission.destroy if permission.persisted?

      # If the user's google_email is not a good google account,
      # we don't want to raise an error since this is based on bad user
      # input. In the future we might want to notify the user somehow.
      # But for now we'll just log it and move on.
      elsif error.message.match?(/cannotShareTeamDriveWithNonGoogleAccounts|invalidSharingRequest.+there is no Google account associated/)
        Rails.logger.warn("User #{permission.google_email} is not a valid google account")
      else
        raise
      end
    end

    private

    def create_permission(permission)
      log("Creating permission", permission)
      result = wrapper.create_permission(
        permission.item_external_id,
        Google::Apis::DriveV3::Permission.new(
          email_address: permission.google_email,
          role: permission.access_level,
          type: "user"
        ),
        send_notification_email: false,
        supports_all_drives: true
      )
      permission.external_id = result.id
      permission.save!
    rescue Google::Apis::ClientError => error
      if error.message.match?(/teamDriveDomainUsersOnlyRestriction/)
        # It is ok to swallow these because they mean that the owner of the shared drive
        # has set the permissions too restrictively so that isn't our fault
        log("Swallowing teamDriveDomainUsersOnlyRestriction", permission)
      else
        raise
      end
    end

    def update_permission_access_level(permission)
      log("Updating permission", permission)
      wrapper.update_permission(
        permission.item_external_id,
        permission.external_id,
        Google::Apis::DriveV3::Permission.new(
          role: permission.access_level
        ),
        supports_all_drives: true
      )
      permission.save!
    rescue Google::Apis::ClientError => error
      if error.message.match?(/notFound: Permission not found/)
        # If the permission was not found, we'll just create it.
        log("Permission not found for item, creating", permission)
        create_permission(permission)
      elsif error.message.match?(/cannotModifyInheritedPermission/)
        # The full error message here was: "Cannot modify a permission on an item to be
        # less than the inherited access from a direct or indirect parent"
        # So it seems ok to swallow this.
        log("Swallowing cannotModifyInheritedPermission because inherited one is higher level", permission)
        permission.destroy
      else
        raise
      end
    end

    def destroy_permission(permission)
      log("Destroying permission", permission)
      wrapper.delete_permission(permission.item_external_id, permission.external_id,
        supports_all_drives: true)
      permission.destroy
    rescue Google::Apis::ClientError => error
      if error.message.match?(/notFound: Permission not found/)
        # If the permission was not found, no problem!
        # Just go ahead and destroy the permission to match.
        log("Permission not found, skipping delete", permission)
        permission.destroy
      elsif error.message.match?(/cannotDeletePermission/)
        # It appears these may be due to the permission being inherited.
        # The full error was "The authenticated user does not have the required
        # access to delete the permission." But it seems unlikely that this is really an "access"
        # issue because the Gather user is generally a super admin, and I was still able to list
        # the permissions when debugging in the Ruby console. So going to log these and swallow them
        # for now.
        log("Swallowing cannotDeletePermission", permission)
        permission.destroy
      elsif error.message.match?(/cannotModifyInheritedTeamDrivePermission/)
        # It is ok to swallow these if we are destroying because it just means the supplemental
        # permission was already destroyed, so it's kind of like the "not found" case
        log("Swallowing cannotModifyInheritedTeamDrivePermission", permission)
        permission.destroy
      else
        raise
      end
    end

    def log(message, permission)
      Rails.logger.info("[GDrive::PermissionSyncJob] #{message}",
        cluster_id: permission.cluster_id,
        access_level: permission.access_level,
        external_id: permission.external_id,
        google_email: permission.google_email,
        item_external_id: permission.item_external_id,
        item_id: permission.item_id,
        user_id: permission.user_id,
      )
    end
  end
end

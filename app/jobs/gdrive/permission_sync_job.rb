# frozen_string_literal: true

module GDrive
  # Parent class for permission sync jobs.
  class PermissionSyncJob < ApplicationJob
    protected

    attr_accessor :community, :wrapper

    def init_api_wrapper
      config = MainConfig.find_by!(community_id: community.id)
      self.wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
    end

    def apply_permission_changes(permission)
      if permission.access_level.nil?
        destroy_permission(permission)
      elsif permission.new_record?
        create_permission(permission)
      elsif permission.google_email_changed?
        new_permission = permission.clone_without_external_id
        destroy_permission(permission)
        create_permission(new_permission)
      elsif permission.access_level_changed?
        update_permission_access_level(permission)
      end
    end

    private

    def create_permission(permission)
      result = wrapper.service.create_permission(
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
    end

    def update_permission_access_level(permission)
      wrapper.service.update_permission(
        permission.item_external_id,
        permission.external_id,
        Google::Apis::DriveV3::Permission.new(
          role: permission.access_level
        ),
        supports_all_drives: true
      )
      permission.save!
    end

    def destroy_permission(permission)
      wrapper.service.delete_permission(permission.item_external_id, permission.external_id,
        supports_all_drives: true)
      permission.destroy!
    end
  end
end

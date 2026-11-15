# frozen_string_literal: true

module GDrive
  # Reads the access levels out of a Google::Apis::DriveV3::Permission.
  #
  # For shared drive items, permissionDetails lists each role the person holds and whether it is
  # inherited from a parent folder or the drive. Other items have no permissionDetails, so their one
  # role is treated as direct.
  module GooglePermissionLevels
    module_function

    # The highest role the person holds directly on the item, or nil if all their access is inherited.
    def direct_level(permission)
      return permission.role if permission.permission_details.blank?

      highest(permission.permission_details.reject(&:inherited).map(&:role))
    end

    # The highest role the person inherits from a parent, or nil if none.
    def inherited_level(permission)
      return nil if permission.permission_details.blank?

      highest(permission.permission_details.select(&:inherited).map(&:role))
    end

    # The highest role the person holds on the item, however they got it.
    def effective_level(permission)
      highest([direct_level(permission), inherited_level(permission)].compact)
    end

    def highest(roles)
      roles.max_by { |r| SyncedPermission.level_index(r) }
    end
  end
end

# frozen_string_literal: true

module GDrive
  # Compares the access Google Drive actually gives people on an item with the access Gather's
  # groups say they should have. It only reads from Google; it changes nothing.
  #
  # It finds two kinds of discrepancy:
  # - missing_access: someone should have a level of access they don't have.
  # - excess_access: someone holds a direct permission above what Gather grants them, e.g. a member
  #   who left the group but whose permission was never removed.
  #
  # Like the sync, it only looks at people Gather knows, by their current google_email. Roles Gather
  # doesn't manage (shared drive Manager, owner) and access inherited from a parent are left alone,
  # since the sync can't change them on this item either.
  class PermissionAudit
    Discrepancy = Struct.new(:kind, :user_id, :expected_level, :actual_level, keyword_init: true)

    attr_reader :wrapper, :item

    def initialize(wrapper:, item:)
      @wrapper = wrapper
      @item = item
    end

    def discrepancies
      expected = expected_levels
      actual = actual_permissions
      missing_access(expected, actual) + excess_access(expected, actual)
    end

    private

    def missing_access(expected, actual)
      expected.filter_map do |user_id, level|
        have = actual[user_id] && GooglePermissionLevels.effective_level(actual[user_id])
        next if index(have) >= index(level)
        Discrepancy.new(kind: :missing_access, user_id: user_id, expected_level: level, actual_level: have)
      end
    end

    def excess_access(expected, actual)
      actual.filter_map do |user_id, permission|
        direct = GooglePermissionLevels.direct_level(permission)
        next if direct.nil? || SyncedPermission::UNMANAGED_ACCESS_LEVELS.include?(direct)
        # The sync can't take anyone below what they inherit, so that's the lowest it can leave.
        allowed = GooglePermissionLevels.highest(
          [expected[user_id], GooglePermissionLevels.inherited_level(permission)].compact
        )
        next if index(direct) <= index(allowed)
        Discrepancy.new(kind: :excess_access, user_id: user_id, expected_level: expected[user_id],
          actual_level: direct)
      end
    end

    # The access each user should have, by user ID. This is the same rule ItemPermissionSyncJob uses.
    def expected_levels
      levels = {}
      ItemGroup.where(item_id: item.id).includes(:group).find_each do |item_group|
        next if item_group.group.deactivated_at.present?
        item_group.group.members.each do |user|
          next if user.deactivated_at.present? || user.google_email.blank?
          levels[user.id] = GooglePermissionLevels.highest([levels[user.id], item_group.access_level].compact)
        end
      end
      levels
    end

    # Google's user permissions on the item for people Gather knows, by user ID.
    def actual_permissions
      user_id_by_email = User.where.not(google_email: nil).pluck(:google_email, :id).to_h
      permissions = {}
      page_token = nil
      loop do
        result = wrapper.list_permissions(item.external_id,
          fields: "permissions(id,emailAddress,role,type,permissionDetails),nextPageToken",
          supports_all_drives: true, page_size: 100, page_token: page_token)
        (result.permissions || []).each do |permission|
          next unless permission.type == "user"
          user_id = user_id_by_email[permission.email_address&.downcase]
          permissions[user_id] = permission if user_id
        end
        page_token = result.next_page_token
        break if page_token.nil?
      end
      permissions
    end

    def index(level)
      SyncedPermission.level_index(level)
    end
  end
end

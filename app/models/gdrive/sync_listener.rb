# frozen_string_literal: true

module GDrive
  # Syncs permission data with Google Drive.
  class SyncListener
    include Singleton

    attr_accessor :last_method_txn_ids

    def create_user_successful(user)
      return if user.google_email.blank?
      item_groups = item_groups_for_user(user)
      return if item_groups.empty?
      enqueue_job([build_job_args_from_item_groups(item_groups, google_email: user.google_email)])
    end

    def update_user_successful(user)
      return unless user.saved_change_to_google_email? ||
        user.saved_change_to_deactivated_at? ||
        user.saved_change_to_full_access? ||
        user_community_changed?(user)

      args = []

      # Remove all permissions for the old google_email, if there was one and it changed.
      if user.saved_change_to_google_email? && user.saved_changes["google_email"][0].present?
        args << build_job_args_from_item_groups([],
          google_email: user.saved_changes["google_email"][0],
          revoke: true)
      end

      # Add current permissions.
      if user.google_email.present?
        item_groups = (user.active? && user.full_access?) ? item_groups_for_user(user) : []
        args << build_job_args_from_item_groups(item_groups, google_email: user.google_email)
      end
      enqueue_job(args)
    end

    def groups_affiliation_committed(affiliation)
      group = affiliation.group
      return unless group.everybody?
      args = group.gdrive_item_groups.map do |item_group|
        build_job_args_from_users(group.members,
          item_external_id: item_group.item_external_id, access_level: item_group.access_level)
      end
      enqueue_job(args)
    end

    private

    def item_groups_for_user(user)
      ItemGroup.where(group: Groups::Group.with_user(user).select(:id)).includes(:item)
    end

    def build_job_args_from_item_groups(item_groups, google_email:, revoke: false)
      permissions = item_groups.map do |item_group|
        {
          item_external_id: item_group.item_external_id,
          access_level: revoke ? nil : item_group.access_level
        }
      end
      {key: :google_email, value: google_email, permissions: permissions}
    end

    def build_job_args_from_users(users, item_external_id:, access_level:)
      permissions = users.map do |user|
        next if user.google_email.blank?
        {
          google_email: user.google_email,
          access_level: access_level
        }
      end.compact
      {key: :item_external_id, value: item_external_id, permissions: permissions}
    end

    def enqueue_job(args)
      return if args.empty?
      PermissionSyncJob.perform_later(args)
    end

    def user_community_changed?(user)
      return false unless user.saved_change_to_household_id?
      old_community_id = Household.find_by(id: user.saved_changes["household_id"][0])&.community_id
      user.community_id != old_community_id
    end
  end
end

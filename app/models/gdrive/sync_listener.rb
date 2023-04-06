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
      enqueue_user_sync(user_id: user.id)
    end

    def update_user_successful(user)
      return unless user.saved_change_to_google_email? ||
        user.google_email.present? && (
          user.saved_change_to_deactivated_at? ||
          user.saved_change_to_full_access? ||
          user_community_changed?(user)
        )

      enqueue_user_sync(user_id: user.id)
    end

    def destroy_user_successful(user)
      return if user.google_email.blank?

      enqueue_user_sync(user_id: user.id)
    end

    def update_household_successful(household)
      return unless household.saved_change_to_community_id?

      household.users.each do |user|
        next if user.google_email.blank?
        enqueue_user_sync(user_id: user.id)
      end
    end

    def gdrive_item_group_committed(item_group)
      enqueue_item_sync(item_id: item_group.item_id)
    end

    def update_groups_group_successful(group)
      return unless group.saved_change_to_availability? || group.saved_change_to_deactivated_at?
      group.gdrive_item_groups.each do |item_group|
        enqueue_item_sync(item_id: item_group.item_id)
      end
    end

    def groups_membership_committed(membership)
      group = membership.group
      group.gdrive_item_groups.each do |item_group|
        enqueue_item_sync(item_id: item_group.item_id)
      end
    end

    def groups_affiliation_committed(affiliation)
      group = affiliation.group
      return unless group.everybody?
      group.gdrive_item_groups.each do |item_group|
        enqueue_item_sync(item_id: item_group.item_id)
      end
    end

    private

    def item_groups_for_user(user)
      ItemGroup.where(group: Groups::Group.with_user(user).select(:id)).includes(:item)
    end

    def enqueue_user_sync(args)
      UserPermissionSyncJob.perform_later(args)
    end

    def enqueue_item_sync(args)
      ItemPermissionSyncJob.perform_later(args)
    end

    def user_community_changed?(user)
      return false unless user.saved_change_to_household_id?
      old_community_id = Household.find_by(id: user.saved_changes["household_id"][0])&.community_id
      user.community_id != old_community_id
    end
  end
end

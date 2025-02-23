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

      enqueue_user_sync(user)
    end

    def update_user_successful(user)
      return unless user.saved_change_to_google_email? ||
        (user.google_email.present? && (
          user.saved_change_to_deactivated_at? ||
          user.saved_change_to_full_access? ||
          user_community_changed?(user)
        ))

      enqueue_user_sync(user)

      if user_community_changed?(user)
        old_household = Household.find_by(id: user.saved_changes["household_id"][0])
        enqueue_user_sync(user, community_id: old_household.community_id) if old_household.present?
      end
    end

    def destroy_user_successful(user)
      return if user.google_email.blank?

      enqueue_user_sync(user)
    end

    def update_household_successful(household)
      return unless household.saved_change_to_community_id?

      household.users.each do |user|
        next if user.google_email.blank?

        enqueue_user_sync(user, community_id: household.community_id)
        enqueue_user_sync(user, community_id: household.saved_changes["community_id"][0])
      end
    end

    def gdrive_item_group_committed(item_group)
      enqueue_item_sync(item_group)
    end

    def update_groups_group_successful(group)
      return unless group.saved_change_to_availability? || group.saved_change_to_deactivated_at?

      enqueue_item_syncs_for_group(group)
    end

    def groups_membership_committed(membership)
      enqueue_item_syncs_for_group(membership.group)
    end

    def groups_affiliation_committed(affiliation)
      group = affiliation.group
      return unless group.everybody?

      enqueue_item_syncs_for_group(group)
    end

    private

    def item_groups_for_user(user)
      GDrive::ItemGroup.where(group: Groups::Group.with_user(user).select(:id)).includes(:item)
    end

    def enqueue_item_syncs_for_group(group)
      group.gdrive_item_groups.includes(item: :gdrive_config).find_each do |item_group|
        enqueue_item_sync(item_group)
      end
    end

    # A user may be moving from one community to another, which may entail
    # changes on two different GDrive configurations. So we allow
    # the caller to specify the community_id to use.
    def enqueue_user_sync(user, community_id: user.community_id)
      return unless MainConfig.exists?(community_id: community_id)

      GDrive::UserPermissionSyncJob.perform_later(cluster_id: user.cluster_id,
                                                  community_id: community_id, user_id: user.id)
    end

    # An ItemGroup is associated with one Item, which is always associated
    # with exactly one community. So we don't need to allow the caller to
    # specify the community_id to use.
    def enqueue_item_sync(item_group)
      item = item_group.item
      config = item.gdrive_config
      GDrive::ItemPermissionSyncJob.perform_later(cluster_id: config.cluster_id,
                                                  community_id: config.community_id, item_id: item.id)
    end

    def user_community_changed?(user)
      return false unless user.saved_change_to_household_id?

      old_community_id = Household.find_by(id: user.saved_changes["household_id"][0])&.community_id
      user.community_id != old_community_id
    end
  end
end

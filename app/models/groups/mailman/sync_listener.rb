# frozen_string_literal: true

module Groups
  module Mailman
    # Syncs users and group data with Mailman.
    class SyncListener
      include Singleton

      def create_user_successful(user)
        return if no_need_to_create_or_update?(user)
        return unless ::Groups::Mailman::User.new(user: user).syncable_with_memberships?
        UserSyncJob.perform_later(user_id: user.id)
      end

      def update_user_successful(user)
        return if no_need_to_create_or_update?(user)
        attribs = %w[email first_name last_name deactivated_at full_access]
        if attribs_changed?(user, %w[deactivated_at full_access])
          # If user is no longer syncable, sign them out. Then they won't be able to sign in again.
          if (mm_user = user.group_mailman_user).present? && !mm_user.syncable?
            SingleSignOnJob.perform_later(user_id: user.id, action: :sign_out)
          end
        end
        if attribs_changed?(user, %w[email first_name last_name]) && user.email.present?
          SingleSignOnJob.perform_later(user_id: user.id, action: :update)
        end
        return unless attribs_changed?(user, attribs) || user_community_changed?(user)
        UserSyncJob.perform_later(user_id: user.id)
      end

      def destroy_user_successful(user)
        return unless (mm_user = user.group_mailman_user)

        # We can't pass the user or the mm_user since the job will fail to load them b/c they're destroyed.
        # So we pass key attribute (remote_id) of the mm_user instead.
        UserSyncJob.perform_later(
          mm_user_attribs: {remote_id: mm_user.remote_id, cluster_id: user.cluster_id},
          destroyed: true
        )

        return if user.group_mailman_user.nil?
        SingleSignOnJob.perform_later(user_id: user.id, cluster_id: user.cluster_id,
          action: :sign_out, destroyed: true)
      end

      def user_signed_out(user)
        return if no_need_to_create_or_update?(user)
        SingleSignOnJob.perform_later(user_id: user.id, action: :sign_out)
      end

      def update_household_successful(household)
        return unless household.saved_change_to_community_id?
        household.users.each { |u| UserSyncJob.perform_later(user_id: u.id) }
      end

      def create_groups_group_successful(group)
        sync_memberships_for_groups_in_same_communities_if_admin_or_mod_perms(group)
      end

      def update_groups_group_successful(group)
        if attribs_changed?(group, %w[can_administer_email_lists can_moderate_email_lists])
          sync_list_memberships_for_groups_in_same_communities(group)
        end

        return unless attribs_changed?(group, %w[availability deactivated_at])
        return if group.mailman_list.nil?
        ListSyncJob.perform_later(list_id: group.mailman_list.id)
      end

      def destroy_groups_group_successful(group)
        sync_memberships_for_groups_in_same_communities_if_admin_or_mod_perms(group)
      end

      def create_groups_mailman_list_successful(list)
        ListSyncJob.perform_later(list_id: list.id)
      end

      def update_groups_mailman_list_successful(list)
        # We don't allow changing the name, domain, or group after the list is created.
        # So these are the only fields we care about, and if they change, we only need
        # to sync members, not the whole list.
        return unless attribs_changed?(list, %w[managers_can_moderate managers_can_administer all_cmty_members_can_send])
        MembershipSyncJob.perform_later("Groups::Mailman::List", list.id)
      end

      def destroy_groups_mailman_list_successful(list)
        # We can't pass the list since the job will fail to load it b/c it's destroyed.
        # So we pass key attribute (remote_id) instead.
        ListSyncJob.perform_later(
          list_attribs: {remote_id: list.remote_id, cluster_id: list.cluster_id},
          destroyed: true
        )
      end

      def groups_membership_committed(membership)
        sync_memberships_for_group_list(membership.group)
        sync_memberships_for_groups_in_same_communities_if_admin_or_mod_perms(membership.group)
      end

      def groups_affiliation_committed(affiliation)
        sync_memberships_for_group_list(affiliation.group)
        sync_memberships_for_groups_in_same_communities_if_admin_or_mod_perms(affiliation.group)
      end

      private

      def sync_memberships_for_groups_in_same_communities_if_admin_or_mod_perms(group)
        return unless group.present?
        return unless group.can_moderate_email_lists? || group.can_administer_email_lists?
        sync_list_memberships_for_groups_in_same_communities(group)
      end

      def sync_memberships_for_group_list(group)
        return unless group.present?
        list = group.mailman_list

        # The list may be unsaved, or destroyed along with the group in this transaction.
        return if list.nil? || !list.persisted?

        # If list doesn't have remote ID, it means ListSyncJob hasn't run yet.
        # We want to run that first. And it will enqueue the MembershipSyncJob.
        # We check the database because ListSyncJob may have set it since the list was loaded.
        return unless ::Groups::Mailman::List.where(id: list.id).where.not(remote_id: nil).exists?
        enqueue_list_membership_sync(list.id)
      end

      # Saving a group can commit many records at once (the group, its affiliations, each of its
      # memberships), and each one calls this. A community can have dozens of lists, so without the
      # `once` checks a single save would queue every list's sync several times over.
      def sync_list_memberships_for_groups_in_same_communities(group)
        communities = group.communities.to_a
        Gather::CommittedTransaction.once([:mailman_lists_in_communities, communities.map(&:id).sort]) do
          # We use in_community since we want to err on the side of syncing more lists than few.
          # Technically if a list has cmtys A & B and the given group has cmty B only, then we will
          # sync the list even though this group doesn't affect that list. But computing it exactly
          # is tricky and this is an edge case and no harm done.
          group_ids = Group.in_community(communities).pluck(:id)
          ::Groups::Mailman::List.where(group_id: group_ids).pluck(:id).each do |list_id|
            enqueue_list_membership_sync(list_id)
          end
        end
      end

      def enqueue_list_membership_sync(list_id)
        Gather::CommittedTransaction.once([:mailman_list_membership_sync, list_id]) do
          MembershipSyncJob.perform_later("Groups::Mailman::List", list_id)
        end
      end

      def no_need_to_create_or_update?(user)
        # If there are currently no sync'd lists and the user doesn't have a sync'd mailman user,
        # there can't be any reason to create a remote user for them, so we can quit early.
        # This is a useful guard to prevent unnecessary HTTP calls, especially in specs.
        ::Groups::Mailman::List.none? && user.group_mailman_user.nil?
      end

      def attribs_changed?(object, attribs)
        (attribs & object.saved_changes.keys).any?
      end

      def user_community_changed?(user)
        return false unless user.saved_change_to_household_id?
        old_community_id = Household.find_by(id: user.saved_changes["household_id"][0])&.community_id
        user.community_id != old_community_id
      end
    end
  end
end

# frozen_string_literal: true

module Groups
  module Mailman
    # Syncs users and group data with Mailman.
    class SyncListener
      include Singleton

      # * On User update (email, name) -- queue user sso update if ever logged in
      # * On User update (deactivate_at, adult), destroy -- queue user sso logout if not eligible (membership deletion will happen via cascading destroy)
      # * On User logout -- queue sso logout

      def create_user_successful(user)
        return if no_need_to_create_or_update?(user)
        return unless Mailman::User.new(user: user).syncable_with_memberships?
        UserSyncJob.perform_later(user_id: user.id)
      end

      def update_user_successful(user)
        return if no_need_to_create_or_update?(user)
        attribs = %w[email first_name last_name deactivated_at adult]
        if attribs_changed?(user, attribs) || user_community_changed?(user)
          UserSyncJob.perform_later(user_id: user.id)
        end
        if attribs_changed?(user, %w[email first_name last_name])
          SingleSignOnJob.perform_later(user_id: user.id, action: :update)
        end
        if attribs_changed?(user, %w[deactivated_at adult]) # rubocop:disable Style/GuardClause
          if (mm_user = user.group_mailman_user).present? && !mm_user.syncable?
            SingleSignOnJob.perform_later(user_id: user.id, action: :sign_out)
          end
        end
      end

      def destroy_user_successful(user)
        return unless (mm_user = user.group_mailman_user)

        # We can't pass the user or the mm_user since the job will fail to load them b/c they're destroyed.
        # So we pass key attribute (remote_id) of the mm_user instead.
        UserSyncJob.perform_later(
          mm_user_attribs: {remote_id: mm_user.remote_id, cluster_id: user.cluster_id},
          destroyed: true
        )

        SingleSignOnJob.perform_later(user_id: user.id, action: :sign_out) if user.group_mailman_user.present?
      end

      def update_household_successful(household)
        return unless household.saved_change_to_community_id?
        household.users.each { |u| UserSyncJob.perform_later(user_id: u.id) }
      end

      def update_groups_group_successful(group)
        if attribs_changed?(group, %w[can_administer_email_lists can_moderate_email_lists])
          group_ids = Group.in_communities(group.communities).pluck(:id)
          Mailman::List.where(group_id: group_ids).pluck(:id).each do |list_id|
            MembershipSyncJob.perform_later("Groups::Mailman::List", list_id)
          end
        end

        return unless attribs_changed?(group, %w[name description availability deactivated_at])
        return if group.mailman_list.nil?
        ListSyncJob.perform_later(list_id: group.mailman_list.id)
      end

      def create_groups_mailman_list_successful(list)
        ListSyncJob.perform_later(list_id: list.id)
      end

      def update_groups_mailman_list_successful(list)
        # The only place where remote_id gets saved is in the ListSyncJob and we don't want
        # to enqueue the MembershipSyncJob in that case because then it will get enqueued twice.
        return if list.saved_change_to_remote_id?
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
        enqueue_membership_sync_job_if_associated_group_has_list(membership)
      end

      def groups_affiliation_committed(affiliation)
        enqueue_membership_sync_job_if_associated_group_has_list(affiliation)
      end

      private

      def no_need_to_create_or_update?(user)
        # If there are currently no sync'd lists and the user doesn't have a sync'd mailman user,
        # there can't be any reason to create a remote user for them, so we can quit early.
        # This is a useful guard to prevent unnecessary HTTP calls, especially in specs.
        Mailman::List.none? && user.group_mailman_user.nil?
      end

      def attribs_changed?(object, attribs)
        (attribs & object.saved_changes.keys).any?
      end

      def user_community_changed?(user)
        return false unless user.saved_change_to_household_id?
        old_community_id = Household.find_by(id: user.saved_changes["household_id"][0])&.community_id
        user.community_id != old_community_id
      end

      def enqueue_membership_sync_job_if_associated_group_has_list(object)
        list = object.group&.mailman_list
        return if list.nil?
        MembershipSyncJob.perform_later("Groups::Mailman::List", list.id)
      end
    end
  end
end

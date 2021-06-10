# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes group memberships to Mailman for a given user or list.
    class MembershipSyncJob < SyncJob
      attr_accessor :source

      def perform(source_class_name, source_id)
        with_object_in_cluster_context(class_name: source_class_name, id: source_id) do |source|
          self.source = source
          return unless source.syncable?
          missing_on_remote, missing_on_local = membership_diff

          # Create any memberships that exist locally but not remotely.
          missing_on_remote.each { |m| create_membership(m) }

          # Delete memberships that match emails of Gather users but don't exist locally.
          # This allows remote memberships for non-Gather users to be managed using the Mailman UI.
          missing_on_local.each { |m| api.delete_membership(m) if email_exists_locally?(m.email) }
        end
      end

      private

      def membership_diff
        local = source.list_memberships
        remote = api.memberships(source)
        [local - remote, remote - local]
      end

      def email_exists_locally?(email)
        # If we're syncing a user we know they exist locally.
        return true if source.is_a?(Groups::Mailman::User)
        local_email_hash.key?(email)
      end

      # Should only be called if source is a list
      def local_email_hash
        @local_email_hash ||= ::User.active.real.in_community(source.communities)
          .pluck(:email).index_by(&:itself)
      end

      def create_membership(mship)
        # `mship` should always have mailman_user set on it by now, though it may not be persisted
        # and may not have a user record.
        # We need to check if the user is syncable (i.e. not fake).
        return unless mship.user_syncable?

        create_or_capture_mailman_user(mship) unless mship.user_remote_id?
        api.update_user(mship.mailman_user) unless correct_email?(mship.mailman_user)
        api.create_membership(mship)
      end

      # Checks if a mailman user exists with the email contained in mship.
      # If one does, stores the remote_id. Otherwise, creates it and stores remote_id.
      def create_or_capture_mailman_user(mship)
        mm_user = mship.mailman_user
        mm_user.remote_id = api.user_id_for_email(mm_user) || api.create_user(mm_user)

        # If the mm_user has a Gather user object assigned, we want to associate the remote_id we just got
        # with it in the database for future API calls, so we save the mm_user. If there is no
        # associated Gather user, then the mm_user record came from e.g. an outside_sender, in which
        # case we can't store the remote ID.
        mm_user.save! if mm_user.user.present?
      end

      def correct_email?(mm_user)
        if source == mm_user
          # Don't call API over and over if source is user
          return @correct_email if defined?(@correct_email)
          @correct_email = api.correct_email?(mm_user)
        else
          api.correct_email?(mm_user)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes group memberships to Mailman for a given user or list.
    class MembershipSyncJob < SyncJob
      attr_accessor :source

      def perform(source_class_name, source_id)
        with_object_in_cluster_context(class_name: source_class_name, id: source_id) do |source|
          self.source = source
          missing, existing, obsolete = membership_diff
          missing.each { |m| create_membership(m) }
          existing.each { |m| update_membership(m) }
          obsolete.each { |m| api.delete_membership(m) }
        end
      end

      private

      def membership_diff
        local = source.list_memberships
        remote = api.memberships(source)
        [local - remote, local & remote, remote - local]
      end

      def create_membership(mship)
        # `mship` should always have mailman_user set on it by now, though it may not be persisted
        # and may not have a user record.
        # We need to check if the user is syncable (i.e. not fake).
        return unless mship.user_syncable?

        create_or_capture_mailman_user(mship) unless mship.user_remote_id?
        api.create_membership(mship)
      end

      def update_membership(mship)
        # No need to check fakeness here if there is already a matching membership on the server.
        create_or_capture_mailman_user(mship) unless mship.user_remote_id?
        api.update_membership(mship)
      end

      # Checks if a mailman user exists with the email contained in mship.
      # If one does, stores the remote_id. Otherwise, creates it and stores remote_id.
      def create_or_capture_mailman_user(mship)
        mm_user = mship.mailman_user
        mm_user.remote_id = api.user_id_for_email(mm_user.email) || api.create_user(mm_user)

        # If the mm_user has a Gather user object assigned, we want to associate the remote_id we just got
        # with it in the database for future API calls, so we save the mm_user. If there is no
        # associated Gather user, then the mm_user record came from e.g. an outside_sender, in which
        # case we can't store the remote ID.
        mm_user.save! if mm_user.user.present?
      end
    end
  end
end

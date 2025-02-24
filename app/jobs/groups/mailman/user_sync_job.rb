# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes Gather users to Mailman users, including list memberships.
    class UserSyncJob < SyncJob
      attr_accessor :user

      def perform(user_id: nil, mm_user_attribs: nil, destroyed: false)
        if destroyed
          # If the user was destroyed, build a temporary Mailman::User with the given attribs,
          # which should include remote_id and cluster_id.
          with_object_in_cluster_context(klass: Mailman::User, attribs: mm_user_attribs) do |mm_user|
            api.delete_user(mm_user)
          end
        else
          # We look up the User object, even though we don't really need it, so that we
          # can establish the cluster with it. We can't use Mailman::User because one doesn't always exist
          # yet when we call the job.
          with_object_in_cluster_context(klass: ::User, id: user_id) do |user|
            if (mm_user = find_mailman_user(user: user))
              sync_with_stored_mailman_user(mm_user)
            else
              sync_without_stored_mailman_user(user)
            end
          end
        end
      end

      private

      # Stubbable in tests
      def find_mailman_user(user:)
        Groups::Mailman::User.find_by(user: user)
      end

      # Stubbable in tests
      def build_mailman_user(user:)
        Groups::Mailman::User.new(user: user)
      end

      def sync_with_stored_mailman_user(mm_user)
        if mm_user.syncable_with_memberships?
          if api.user_exists?(mm_user)
            update_user_and_memberships(mm_user)
          else
            mm_user.destroy
            self.class.perform_later(mm_user.user_id)
          end
        else
          api.delete_user(mm_user)
        end
      end

      def sync_without_stored_mailman_user(user)
        mm_user = build_mailman_user(user: user)
        mm_user.remote_id = api.user_id_for_email(mm_user)
        if mm_user.syncable_with_memberships?
          # If user already exists with local user's email, unify them and update
          if mm_user.remote_id?
            ensure_no_duplicate_user(mm_user.remote_id)
            update_user_and_memberships(mm_user)
          else
            create_user_and_memberships(mm_user)
          end
        # If there is a remote user with a matching email and the local user is not syncable, we need
        # to delete that remote user.
        elsif mm_user.remote_id?
          api.delete_user(mm_user)
        end
      end

      def ensure_no_duplicate_user(remote_id)
        return unless Groups::Mailman::User.find_by(remote_id: remote_id)

        raise SyncError, "duplicate mailman user found for mailman ID #{remote_id}"
      end

      def update_user_and_memberships(mm_user)
        mm_user.save!
        api.update_user(mm_user)
        MembershipSyncJob.perform_later("Groups::Mailman::User", mm_user.id)
      end

      def create_user_and_memberships(mm_user)
        new_remote_id = api.create_user(mm_user)
        mm_user.update!(remote_id: new_remote_id)
        MembershipSyncJob.perform_later("Groups::Mailman::User", mm_user.id)
      end
    end
  end
end

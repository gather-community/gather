# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes Gather users to Mailman users, including list memberships.
    class UserSyncJob < SyncJob
      attr_accessor :user

      def perform(user)
        # A note on error handling: Generally in this class we have tried to make it so that it is highly
        # unlikely that we would encounter 4xx-type errors (invalid input). We have done this by e.g.
        # checking for the existence of a remote user before attempting to update it. So if those
        # kind of errors occur, we'd want them to be handled by the job system and reported to admins.
        # We are never immune to 5xx, of course, if e.g. the Mailman server is down. In that case, we would
        # also want to see those errors.
        self.user = user
        with_community(user.community) do
          if (mm_user = Groups::Mailman::User.find_by(user: user))
            sync_with_stored_mailman_user(mm_user)
          else
            sync_without_stored_mailman_user
          end
        end
      end

      private

      def api
        Api.instance
      end

      def sync_with_stored_mailman_user(mm_user)
        if mm_user.syncable?
          if api.user_exists?(id: mm_user.mailman_id)
            update_user_and_memberships(mm_user)
          else
            mm_user.destroy
            self.class.perform_later(user)
          end
        else
          api.delete_user(id: mm_user.mailman_id)
        end
      end

      def sync_without_stored_mailman_user
        mm_user = Groups::Mailman::User.new(user: user)
        mailman_id = api.find_user_id(email: user.email)
        if mm_user.syncable?
          # If user already exists with local user's email, unify them and update
          if mailman_id
            ensure_no_duplicate_user(mailman_id)
            mm_user.update!(mailman_id: mailman_id)
            update_user_and_memberships(mm_user)
          else
            mm_user.update!(mailman_id: api.create_user(base_attributes))
            UserMembershipSyncJob.perform_later(mm_user)
          end
        # If there is a remote user with a matching email and the local user is not syncable, we need
        # to delete that remote user.
        elsif mailman_id.present?
          api.delete_user(id: mailman_id)
        end
      end

      def ensure_no_duplicate_user(mailman_id)
        return unless Groups::Mailman::User.find_by(mailman_id: mailman_id)
        raise SyncError, "duplicate mailman user found for mailman ID #{mailman_id}"
      end

      def update_user_and_memberships(mm_user)
        attribs = base_attributes.merge(id: mm_user.mailman_id)
        api.update_user(attribs)
        UserMembershipSyncJob.perform_later(mm_user)
      end

      def base_attributes
        user.attributes.symbolize_keys.slice(:first_name, :last_name, :email)
      end
    end
  end
end

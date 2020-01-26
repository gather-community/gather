# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes Gather users to Mailman users, including list memberships.
    class UserSyncJob < SyncJob
      attr_accessor :user

      def perform(user)
        self.user = user
        with_community(user.community) do
          if (mm_user = Groups::Mailman::User.find_by(user: user))
            if mm_user.syncable?
              if api.user_exists?(id: mm_user.mailman_id)
                attribs = user.attributes.symbolize_keys
                  .slice(:first_name, :last_name, :email).merge(id: mm_user.mailman_id)
                api.update_user(attribs)
                UserMembershipSyncJob.perform_later(user)
              else
                mm_user.destroy
                self.class.perform_later(user)
              end
            else
              api.delete_user(id: mm_user.mailman_id)
            end
          end
        end
      end

      private

      def api
        Api.instance
      end
    end
  end
end

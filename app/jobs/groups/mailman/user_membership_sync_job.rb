# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes group memberships to Mailman for a given user.
    class UserMembershipSyncJob < SyncJob
      attr_accessor :user

      def perform(user)
        self.user = user
      end
    end
  end
end

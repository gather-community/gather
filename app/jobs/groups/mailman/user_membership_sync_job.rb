# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes group memberships to Mailman for a given user.
    class UserMembershipSyncJob < SyncJob
      attr_accessor :mailman_user

      def perform(mailman_user_id)
        with_object_in_community_context(Mailman::User, mailman_user_id) do |mailman_user|
          self.mailman_user = mailman_user
          missing, existing, obsolete = membership_diff
          missing.each { |m| api.create_membership(m) }
          existing.each { |m| api.update_membership(m) }
          obsolete.each { |m| api.delete_membership(m) }
        end
      end

      private

      def membership_diff
        local = mailman_user.list_memberships
        remote = remote_memberships
        [local - remote, local & remote, remote - local]
      end

      def remote_memberships
        api.memberships_for(user_id: mailman_user.remote_id).map do |m|
          ListMembership.new(mailman_user: mailman_user, list_id: m[:list_id], role: m[:role])
        end
      end
    end
  end
end

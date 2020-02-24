# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes group memberships to Mailman for a given user or list.
    class MembershipSyncJob < SyncJob
      attr_accessor :source

      def perform(source_class, source_id)
        with_object_in_community_context(source_class.constantize, source_id) do |source|
          self.source = source
          missing, existing, obsolete = membership_diff
          missing.each { |m| api.create_membership(m) }
          existing.each { |m| api.update_membership(m) }
          obsolete.each { |m| api.delete_membership(m) }
        end
      end

      private

      def membership_diff
        local = source.list_memberships
        remote = api.memberships(source)
        [local - remote, local & remote, remote - local]
      end
    end
  end
end

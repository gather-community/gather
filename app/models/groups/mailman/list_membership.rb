# frozen_string_literal: true

module Groups
  module Mailman
    # A membership of a user in a mailman list. Ephemeral model used during sync.
    # Different, but computed from, from a membership in a group, which is persisted.
    class ListMembership
      include ActiveModel::Model

      attr_accessor :remote_id, :mailman_user, :list_id, :role, :moderation_action, :display_name, :by_address

      delegate :email, to: :mailman_user
      delegate :syncable?, :remote_id, :remote_id?, to: :mailman_user, prefix: "user"

      # We compare based on email and list_id because those are the two key pieces.
      # user_remote_id may or may not be available depending on what this ListMembership was built from.
      def ==(other)
        email == other.email && list_id == other.list_id && role == other.role
      end

      def eql?(other)
        self == other
      end

      def hash
        [email, list_id, role].hash
      end

      def name_or_email
        @name_or_email ||= display_name.presence || email
      end

      def subscriber
        # We prefer to subscribe by user_id so that we are subscribing via preferred address.
        # Then when we change the user's preferred address, we don't have to change all their memberships.
        # So if mailman_user is set, we use that.
        # In testing sometimes we want to subscribe by address so we support that via the
        # by_address flag.
        by_address ? email : user_remote_id
      end
    end
  end
end

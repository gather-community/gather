# frozen_string_literal: true

module Groups
  module Mailman
    # A membership of a user in a mailman list. Ephemeral model used during sync.
    # Different, but computed from, from a membership in a group, which is persisted.
    class ListMembership
      include ActiveModel::Model

      attr_accessor :id, :mailman_user, :list_id, :role
      attr_writer :email

      def email
        mailman_user.present? ? mailman_user.email : @email
      end

      def user_remote_id
        mailman_user&.remote_id
      end

      # We compare based on email and list_id because those are the two key pieces.
      # user_remote_id may or may not be available depending on what this ListMembership was built from.
      def ==(other)
        email == other.email && list_id == other.list_id
      end

      def eql?(other)
        self == other
      end

      def hash
        [email, list_id].hash
      end
    end
  end
end

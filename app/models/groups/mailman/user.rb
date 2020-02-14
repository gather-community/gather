# frozen_string_literal: true

module Groups
  module Mailman
    # Wrapper class that links a mailman user to a Gather user
    class User < ApplicationRecord
      acts_as_tenant :cluster

      delegate :first_name, :last_name, :email, :community, to: :user

      belongs_to :user, class_name: "::User", inverse_of: :group_mailman_user

      def display_name
        "#{first_name} #{last_name}"
      end

      def remote_id?
        remote_id.present?
      end

      # Whether this user needs an account on the Mailman server.
      def syncable?
        !user.fake? && list_memberships.any?
      end

      def list_memberships
        @list_memberships ||= Groups::User.new(user: user).computed_memberships.map do |mship|
          next if mship.opt_out?
          next unless (list = mship.group.mailman_list)
          ListMembership.new(mailman_user: self, list_id: list.remote_id, role: kind_to_role(mship.kind))
        end.compact
      end

      private

      def kind_to_role(kind)
        case kind
        when "joiner" then "member"
        when "manager" then "owner"
        end
      end
    end
  end
end

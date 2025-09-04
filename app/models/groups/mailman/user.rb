# frozen_string_literal: true

# == Schema Information
#
# Table name: group_mailman_users
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  remote_id  :string           not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
module Groups
  module Mailman
    # Wrapper class that links a mailman user to a Gather user
    class User < ApplicationRecord
      acts_as_tenant :cluster

      attr_writer :display_name, :email

      delegate :community, to: :user

      belongs_to :user, class_name: "::User", inverse_of: :group_mailman_user

      def display_name
        user.present? ? "#{user.first_name} #{user.last_name}" : @display_name
      end

      def email
        user.present? ? user.email : @email
      end

      def remote_id?
        remote_id.present?
      end

      # Whether this user is eligible for an account on the Mailman server.
      def syncable?
        # If user is nil, this is a non-persisted instance so it must be syncable, else it wouldn't
        # have been built.
        user.nil? || (!user.fake? && user.active? && user.full_access?)
      end

      def syncable_with_memberships?
        syncable? && list_memberships.any?
      end

      def list_memberships
        @list_memberships ||= Groups::User.new(user: user).computed_memberships.flat_map do |mship|
          next if mship.opt_out?
          next unless (list = mship.group.mailman_list)
          list.list_memberships_for_group_membership_and_mm_user(mship, self)
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

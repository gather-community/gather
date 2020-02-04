# frozen_string_literal: true

module Groups
  module Mailman
    # Links a mailman user to a Gather user
    class User < ApplicationRecord
      acts_as_tenant :cluster

      delegate :first_name, :last_name, :email, to: :user

      belongs_to :user, class_name: "::User", inverse_of: :group_mailman_user

      def mailman_id?
        mailman_id.present?
      end

      # Whether this user needs an account on the Mailman server.
      def syncable?
        return false if user.fake?
        with_user = Groups::Group.with_user(user).pluck(:id)
        with_mailman = List.all.pluck(:group_id)
        (with_user & with_mailman).any?
      end
    end
  end
end

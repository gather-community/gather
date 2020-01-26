# frozen_string_literal: true

module Groups
  module Mailman
    # Links a mailman user to a Gather user
    class User < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :user, class_name: "::User", inverse_of: :group_mailman_user

      def syncable?
      end
    end
  end
end

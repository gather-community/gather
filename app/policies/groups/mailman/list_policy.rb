# frozen_string_literal: true

module Groups
  module Mailman
    class ListPolicy < ApplicationPolicy
      alias_method :list, :record

      def edit?
        active? && list.group && group_policy.appropriate_admin?
      end

      def edit_name?
        edit? && list.new_record?
      end

      def sync?
        list.group && group_policy.show?
      end

      private

      def group_policy
        @group_policy ||= GroupPolicy.new(user, list.group)
      end
    end
  end
end

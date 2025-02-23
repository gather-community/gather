# frozen_string_literal: true

module Groups
  module Mailman
    class ListPolicy < ApplicationPolicy
      alias list record

      def new?
        active? && list.group && group_policy.appropriate_admin?
      end

      def edit?
        new?
      end

      def edit_name?
        edit? && list.new_record?
      end

      def sync?
        list.group && group_policy.show?
      end

      def destroy?
        new?
      end

      private

      def group_policy
        @group_policy ||= GroupPolicy.new(user, list.group)
      end
    end
  end
end

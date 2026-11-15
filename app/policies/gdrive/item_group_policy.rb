# frozen_string_literal: true

module GDrive
  class ItemGroupPolicy < ApplicationPolicy
    alias_method :item_group, :record

    class Scope < Scope
      def resolve
        return scope.none unless user.active? && user.full_access?
        # Same rule as the permission sync: active groups the user belongs to, counting only groups
        # affiliated with the user's community.
        scope.where(group: Groups::Group.with_user(user).active.select(:id))
      end
    end

    def new?
      active_admin?
    end

    def create?
      active_admin?
    end

    def destroy?
      active_admin?
    end

    def permitted_attributes
      %i[access_level group_id item_id]
    end
  end
end

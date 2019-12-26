# frozen_string_literal: true

module Groups
  class GroupPolicy < ApplicationPolicy
    alias group record

    class Scope < Scope
      def resolve
        if active_cluster_admin?
          scope
        elsif active_admin?
          scope.in_community(user.community)
        elsif active?
          scope.in_community(user.community).visible
        else
          scope.none
        end
      end
    end

    def index?
      active?
    end

    def show?
      active? && (appropriate_admin? || !group.hidden? && user_in_any_community?)
    end

    def create?
      active? && appropriate_admin?
    end

    def update?
      active? && (appropriate_admin? || group.memberships.managers.pluck(:user_id).include?(user.id))
    end

    def destroy?
      active? && appropriate_admin?
    end

    private

    def appropriate_admin?
      user.global_role?(:cluster_admin) && group.cluster == user.cluster ||
        !group.multi_community? && user.global_role?(:admin) && user_in_any_community?
    end

    def user_in_any_community?
      group.communities.include?(user.community)
    end
  end
end

# frozen_string_literal: true

module Groups
  class GroupPolicy < ApplicationPolicy
    alias group record

    def index?
      active?
    end

    def show?
      active? && (admin_in_any_community? || !group.hidden? && user_in_any_community?)
    end

    def create?
      active? && admin_in_any_community?
    end

    def update?
      active? && (admin_in_any_community? || group.memberships.managers.pluck(:user_id).include?(user.id))
    end

    def destroy?
      active? && admin_in_any_community?
    end

    private

    def admin_in_any_community?
      user.global_role?(:admin) && user_in_any_community? ||
        user.global_role?(:cluster_admin) && group.cluster == user.cluster
    end

    def user_in_any_community?
      group.communities.include?(user.community)
    end
  end
end

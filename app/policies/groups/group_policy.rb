# frozen_string_literal: true

module Groups
  class GroupPolicy < ApplicationPolicy
    alias group record

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

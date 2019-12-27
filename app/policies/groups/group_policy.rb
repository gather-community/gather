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

    def activate?
      active? && group.inactive? && appropriate_admin?
    end

    def deactivate?
      active? && group.active? && appropriate_admin?
    end

    def destroy?
      active? && appropriate_admin?
    end

    def permitted_attributes
      permitted = %i[availability can_request_jobs description kind name]
      permitted << {memberships_attributes: %i[id kind user_id _destroy]}
      permitted << {community_ids: []} if user.global_role?(:cluster_admin) || user.global_role?(:super_admin)
      permitted
    end

    private

    def appropriate_admin?
      user.global_role?(:super_admin) ||
        user.global_role?(:cluster_admin) && group.cluster == user.cluster ||
        user.global_role?(:admin) && !group.multi_community? && user_in_any_community?
    end

    def user_in_any_community?
      group.communities.include?(user.community)
    end
  end
end

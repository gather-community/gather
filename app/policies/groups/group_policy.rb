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
          scope.in_community(user.community).visible_or_managed_by(user).active
        else
          scope.none
        end
      end
    end

    def index?
      active?
    end

    def show?
      active? && (appropriate_admin? || manager? || !group.hidden? && record_tied_to_user_community?)
    end

    def create?
      active? && appropriate_admin?
    end

    def update?
      active? && (appropriate_admin? || manager?)
    end

    def activate?
      active? && group.inactive? && appropriate_admin?
    end

    def deactivate?
      active? && group.active? && appropriate_admin?
    end

    def join?
      group.everybody? && membership&.opt_out? || group.open? && membership.nil?
    end

    def leave?
      group.everybody? && (membership.nil? || !membership.opt_out?) || !group.everybody? && !membership.nil?
    end

    def destroy?
      active? && appropriate_admin?
    end

    def change_permissions?
      active? && appropriate_admin?
    end

    def edit_list?
      active? && appropriate_admin?
    end

    def permitted_attributes
      permitted = %i[availability description kind name]
      if change_permissions?
        permitted.concat(%i[can_request_jobs can_administer_email_lists can_moderate_email_lists])
      end
      if edit_list?
        permitted.concat([mailman_list_attributes: %i[id name domain_id _destroy
                                                      managers_can_administer managers_can_moderate]])
      end
      permitted << {memberships_attributes: %i[id kind user_id _destroy]}
      permitted << {community_ids: []} if user.global_role?(:cluster_admin) || user.global_role?(:super_admin)
      permitted
    end

    private

    def appropriate_admin?
      user.global_role?(:super_admin) ||
        user.global_role?(:cluster_admin) && group.cluster == user.cluster ||
        user.global_role?(:admin) && record_tied_to_user_community?
    end

    def membership
      @membership ||= group.membership_for(user)
    end

    def manager?
      @manager ||= group.memberships.managers.pluck(:user_id).include?(user.id)
    end
  end
end

# frozen_string_literal: true

module Groups
  class GroupPolicy < ApplicationPolicy
    alias group record

    def index?
      active?
    end

    def show?
      active? && (
        ((!group.hidden? || user.global_role?(:admin)) && group.communities.include?(user.community)) ||
        (user.global_role?(:cluster_admin) && group.cluster == user.cluster)
      )
    end
  end
end

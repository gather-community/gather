# frozen_string_literal: true

module Work
  class ShiftPolicy < ApplicationPolicy
    alias shift record

    class Scope < Scope
      def resolve
        community_only_unless_cluster_admin
      end
    end

    def index?
      active_in_community?
    end

    def show?
      index?
    end

    def signup?
      index? && (shift.period_open? || shift.period_published?) &&
        !shift.user_signed_up?(user) && !shift.taken?
    end

    def unsignup?
      shift.period_open? && index?
    end

    def new?
      active_admin_or?(:work_coordinator)
    end

    def edit?
      new?
    end

    def create?
      new?
    end

    def update?
      new?
    end

    def destroy?
      new?
    end
  end
end

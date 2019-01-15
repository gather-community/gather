# frozen_string_literal: true

module Meals
  class RolePolicy < ApplicationPolicy
    alias role record

    class Scope < Scope
      def resolve
        allow_admins_in_community_or(:meals_coordinator)
      end
    end

    def index?
      active_admin_or?(:meals_coordinator)
    end

    def show?
      index?
    end

    def new?
      index?
    end

    def edit?
      index?
    end

    def create?
      index?
    end

    def update?
      index?
    end

    def activate?
      index? && Role.where(title: role.title).active.none?
    end

    def deactivate?
      index? && role.active? && !role.head_cook?
    end

    def destroy?
      index? && !role.head_cook? && Meals::FormulaRole.where(role: record).none?
    end

    def permitted_attributes
      %i[description time_type title double_signups_allowed count_per_meal shift_start shift_end] <<
        {reminders_attributes: %i[rel_magnitude rel_unit_sign note id _destroy]}
    end
  end
end

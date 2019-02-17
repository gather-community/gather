# frozen_string_literal: true

module Meals
  class FormulaPolicy < ApplicationPolicy
    alias formula record

    delegate :has_meals?, :is_default?, to: :formula

    class Scope < Scope
      def resolve
        if active_admin_or?(:meals_coordinator)
          scope
        else
          scope.active
        end
      end
    end

    def index?
      active_in_cluster?
    end

    def show?
      active_in_cluster?
    end

    def create?
      active_admin_or?(:meals_coordinator)
    end

    def update?
      active_admin_or?(:meals_coordinator)
    end

    def update_calcs?
      !has_meals? && active_admin_or?(:meals_coordinator)
    end

    def activate?
      formula.inactive? && active_admin_or?(:meals_coordinator)
    end

    def deactivate?
      !is_default? && formula.active? && active_admin_or?(:meals_coordinator)
    end

    def destroy?
      !is_default? && update_calcs?
    end

    def permitted_attributes
      attrs = %i[name is_default pantry_reimbursement] << {role_ids: []}
      if update_calcs?
        attrs.push(:meal_calc_type, :pantry_calc_type, :pantry_fee_disp)
        Signup::SIGNUP_TYPES.map { |st| attrs << :"#{st}_disp" }
      end
      attrs
    end
  end
end

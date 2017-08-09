module Meals
  class FormulaPolicy < ApplicationPolicy
    alias_method :formula, :record

    delegate :has_meals?, :is_default?, to: :formula

    class Scope < ApplicationPolicy::Scope
      def resolve
        if active_admin_or_meals_coordinator?
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
      active_admin_or_meals_coordinator?
    end

    def update?
      !has_meals? && active_admin_or_meals_coordinator?
    end

    def activate?
      active_admin_or_meals_coordinator?
    end

    def deactivate?
      !is_default? && active_admin_or_meals_coordinator?
    end

    def destroy?
      !is_default? && update?
    end

    def permitted_attributes
      [:name, :is_default, :meal_calc_type, :pantry_calc_type, :pantry_fee] +
        Signup::SIGNUP_TYPES.map(&:to_sym)
    end
  end
end

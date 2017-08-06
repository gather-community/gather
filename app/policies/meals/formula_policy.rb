module Meals
  class FormulaPolicy < ApplicationPolicy
    alias_method :formula, :record

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
      !formula.has_meals? && active_admin_or_meals_coordinator?
    end

    def activate?
      active_admin_or_meals_coordinator?
    end

    def deactivate?
      active_admin_or_meals_coordinator?
    end

    def destroy?
      update?
    end
  end
end

module Meals
  class FormulaPolicy < ApplicationPolicy
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
      active_admin_or_meals_coordinator?
    end

    def activate?
      active_admin_or_meals_coordinator?
    end

    def deactivate?
      active_admin_or_meals_coordinator?
    end

    def destroy?
      active_admin_or_meals_coordinator?
    end
  end
end

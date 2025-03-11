# frozen_string_literal: true

module Meals
  class RestrictionPolicy < ApplicationPolicy
    alias restriction record

    delegate :meals?, :is_default?, to: :restriction

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
      !meals? && active_admin_or?(:meals_coordinator)
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
      attrs = %i[contains abscence deactivated_at] << {role_ids: []}
      puts "ATTRS ~~~~~ #{attrs}"
    end
  end
end

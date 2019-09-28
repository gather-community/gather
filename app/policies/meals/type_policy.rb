# frozen_string_literal: true

module Meals
  class TypePolicy < ApplicationPolicy
    alias type record

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
      index? && type.inactive?
    end

    def deactivate?
      index? && type.active?
    end

    def destroy?
      index? && Meals::FormulaPart.where(type: record).none? &&
        Meals::SignupPart.where(type: record).none? &&
        Meals::CostPart.where(type: record).none?
    end

    def permitted_attributes
      %i[name category]
    end
  end
end

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

    def permitted_attributes
      %i[name category]
    end
  end
end

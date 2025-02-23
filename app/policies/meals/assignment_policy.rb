# frozen_string_literal: true

module Meals
  class AssignmentPolicy < ApplicationPolicy
    alias assignment record

    def destroy?
      assigned_user = assignment.user
      active_admin_or?(:meals_coordinator) || (active? && user.household_id == assigned_user.household_id)
    end
  end
end

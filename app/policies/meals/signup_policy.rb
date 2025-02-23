# frozen_string_literal: true

module Meals
  class SignupPolicy < ApplicationPolicy
    alias signup record

    delegate :meal, to: :signup

    def create?
      active? && invited? && meal.open? && !meal.cancelled? && !meal.full? && !meal.in_past?
    end

    def update?
      invited? && meal.open? && !meal.in_past?
    end

    def permitted_attributes
      [:id, :household_id, :meal_id, :takeout, :comments, {parts_attributes: %i[id type_id count _destroy]}]
    end

    private

    def invited?
      # Compare IDs to prevent N+1 in meals index
      meal.invitations.any? { |invitation| invitation.community_id == user.community_id }
    end
  end
end

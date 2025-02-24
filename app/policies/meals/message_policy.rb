# frozen_string_literal: true

module Meals
  class MessagePolicy < ApplicationPolicy
    def show?
      false
    end

    def create?
      raise ArgumentError, "Meal must be set on Message to check permissions" if record.meal.nil?
      return @create if defined?(@create)

      @create = MealPolicy.new(user, record.meal).send_message?
    end

    def permitted_attributes
      %i[kind body recipient_type]
    end
  end
end

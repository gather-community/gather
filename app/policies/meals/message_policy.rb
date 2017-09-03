module Meals
  class MessagePolicy < ApplicationPolicy
    def show?
      false
    end

    def create?
      raise ArgumentError.new("Meal must be set on Message to check permissions") if record.meal.nil?
      return @create if defined?(@create)
      @create = MealPolicy.new(user, record.meal).send_message?
    end
  end
end

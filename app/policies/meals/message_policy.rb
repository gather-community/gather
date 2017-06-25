module Meals
  class MessagePolicy < ApplicationPolicy
    def show?
      false
    end

    def create?
      raise ArgumentError.new("Meal must be set on Message to chec permissions") if record.meal.nil?
      record.meal.assignments.map(&:user_id).include?(user.id)
    end
  end
end

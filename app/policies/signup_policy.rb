# frozen_string_literal: true

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
    Signup::SIGNUP_TYPES + %i[meal_id comments]
  end

  private

  def invited?
    signup.communities.include?(user.community)
  end
end

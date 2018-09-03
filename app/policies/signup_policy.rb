# frozen_string_literal: true

class SignupPolicy < ApplicationPolicy
  alias signup record

  def create?
    active? && invited?
  end

  def update?
    invited?
  end

  def permitted_attributes
    Signup::SIGNUP_TYPES + %i[meal_id comments]
  end

  private

  def invited?
    signup.communities.include?(user.community)
  end
end

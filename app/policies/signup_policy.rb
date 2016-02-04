class SignupPolicy < ApplicationPolicy
  alias_method :signup, :record

  def create?
    invited?
  end

  def update?
    invited?
  end

  def permitted_attributes
    Signup::SIGNUP_TYPES + [:meal_id, :comments]
  end

  private

  def invited?
    signup.communities.include?(user.community)
  end
end

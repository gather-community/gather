class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    # Anyone can read any other user's info.
    can :read, User

    # User can edit own profile.
    can :update, User, id: user.id

    # Anyone can view all meals
    can :read, Meal
    can :work_calendar, Meal

    # Head cooks can edit meals
    can :update, Meal do |meal|
      meal.head_cook == user
    end

    if user.admin?
      # Admins can edit any user or meal
      can :manage, User
      can :manage, Meal
    end
  end
end

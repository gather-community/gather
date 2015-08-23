class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    # Anyone can read any other user's info.
    can :read, User

    # User can edit own profile.
    can :update, User, id: user.id

    # Anyone can view all meals
    can [:read, :work_calendar], Meal, Meal.visible_to(user) do |meal|
      meal.visible_to?(user)
    end

    # Head cooks can edit meals
    can :update, Meal do |meal|
      meal.head_cook == user
    end

    # Can signup for meal if invited
    can [:create, :update, :destroy], Signup do |signup|
      signup.meal.communities.include?(user.community)
    end

    if user.admin?
      can :manage, User
      can :manage, Meal
      can :manage, Signup
    end
  end
end

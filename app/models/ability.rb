class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    # Anyone can read any other user or household's basic info.
    can :read, User

    # User can edit own profile.
    can :update, User, id: user.id

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
      can :manage, Meal, Meal.visible_to(user) do |meal|
        meal.visible_to?(user)
      end
      can :manage, Signup
      can :manage, Household
    else
      # Anyone can view all meals
      can [:read, :work], Meal, Meal.visible_to(user) do |meal|
        meal.visible_to?(user)
      end
    end

    cannot :manage_other_community, Meal # This will change later for superadmin

    cannot :destroy, User do |u|
      u.any_assignments?
    end

    cannot :destroy, Household do |h|
      h.any_assignments? || h.any_signups? || h.any_users?
    end
  end
end

class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    # Anyone can index any active user or household's basic info.
    can :index, User, deactivated_at: nil

    # Can show inactive users too, in case there are links out there, don't want to break them.
    can :show, User

    # User can edit own profile.
    can :update, User, id: user.id

    # Head cooks can edit meals
    can [:update, :close, :reopen, :summary], Meal do |meal|
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
      h.any_assignments? || h.any_signups? || h.any_users? || h.any_line_items? || h.any_invoices?
    end

    cannot :summary, Meal do |m|
      m.open?
    end
  end
end

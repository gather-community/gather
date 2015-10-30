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

    # Can see own account and invoices.
    can :show, Account, household_id: user.household_id
    can :show, Invoice, household_id: user.household_id

    # Can see all accounts and invoices if biller or admin.
    if user.admin? || user.biller?
      can :read, Account
      can :manage, Invoice, Invoice.for_community(user.community) do |invoice|
        invoice.community_id == user.community_id
      end
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

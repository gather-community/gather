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
    can [:update, :set_menu, :close, :reopen, :summary], Meal do |meal|
      meal.head_cook == user
    end

    # Can signup for meal if invited
    can [:create, :update, :destroy], Signup do |signup|
      signup.meal.communities.include?(user.community)
    end

    # Can see all accounts and statements if biller or admin.
    if user.admin? || user.biller?
      can [:finalize, :do_finalize], Meal
      can :read, Household
      can :manage, Account, Account.for_community_or_household(user.community, user.household) do |account|
        account.community_id == user.community_id || account.household_id == user.household_id
      end
      can :manage, Statement, Statement.for_community_or_household(user.community, user.household) do |statement|
        statement.community_id == user.community_id || statement.household_id == user.household_id
      end
      can :manage, Transaction, Transaction.for_community_or_household(user.community, user.household) do |txn|
        txn.community_id == user.community_id || txn.household_id == user.household_id
      end
    else
      # Can see own accounts and statements.
      can :accounts, Household, id: user.household_id
      can :show, Account, household_id: user.household_id
      can :read, Statement, household_id: user.household_id
      can :read, Transaction, Transaction.for_household(user.household) do |txn|
        txn.household_id == user.household_id
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
      # Anyone can view all meals or change workers with notification.
      can [:read, :work, :update], Meal, Meal.visible_to(user) do |meal|
        meal.visible_to?(user)
      end
    end

    cannot :destroy, User do |u|
      u.any_assignments?
    end

    cannot :destroy, Household do |h|
      h.any_assignments? || h.any_signups? || h.any_users? || h.any_transactions? || h.any_statements?
    end
  end
end

class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    # Anyone can read any other user's info.
    can :read, User

    # User can edit own profile.
    can :update, User, id: user.id

    if user.admin?
      # Admins can edit any user
      can :manage, User
    end
  end
end

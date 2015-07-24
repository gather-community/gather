class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    # Anyone can read any other user's info.
    can :read, User

    # Only user can edit own profile.
    can :edit_profile, User, id: user.id

    if user.admin?
      # Admins can edit any user
      can :manage, User
    end
  end
end

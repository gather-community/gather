# frozen_string_literal: true

module ApplicationControllable::Loaders
  extend ActiveSupport::Concern

  included do
    helper_method :load_showable_users_and_children_in, :load_communities_in_cluster
  end

  protected

  def load_communities_in_cluster
    @communities = current_cluster.communities.by_name
  end

  # Users and children related to the given household that are active
  # and that the UserPolicy says we can show.
  def load_showable_users_and_children_in(household, show_inactive_if_allowed: false)
    return [] if household.no_users?

    users = UserPolicy::Scope.new(current_user, User).resolve
    # If the current user is allowed to see inactive users but we don't want them to, respect that.
    # If they're not allowed to see inactive users, this won't have any effect.
    users = users.active unless show_inactive_if_allowed
    users
      .in_household(household)
      .inactive_last
      .by_name_adults_first
      .decorate
  end
end

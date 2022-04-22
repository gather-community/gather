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
  def load_showable_users_and_children_in(household, show_inactive_for_admins: false)
    UserPolicy.new(current_user, User)
      .filter(household.users_and_children, show_inactive_for_admins: show_inactive_for_admins)
      .map(&:decorate)
  end
end

module Concerns::ApplicationController::Loaders
  extend ActiveSupport::Concern

  included do
    helper_method :load_showable_users_and_children_in, :load_communities_in_cluster
  end

  protected

  def lens_communities
    if lens[:community] == "all" || lens[:community].blank?
      current_cluster.communities
    else
      current_community
    end
  end

  def load_communities_in_cluster
    @communities = current_cluster.communities.by_name
  end

  # Users and children related to the given household that are active
  # and that the UserPolicy says we can show.
  def load_showable_users_and_children_in(household)
    UserPolicy.new(current_user, User).filter(household.users_and_children).map(&:decorate)
  end
end

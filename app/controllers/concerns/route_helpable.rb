module RouteHelpable
  extend ActiveSupport::Concern

  included do
    helper_method :reservations_path_for_community,
      :reservations_path_for_resource,
      :new_reservation_path_for_resource
  end

  def reservations_path_for_community(community)
    reservations_path(community: community.abbrv.downcase)
  end

  def reservations_path_for_resource(resource)
    reservations_path(community: resource.community.abbrv.downcase, resource_id: resource.id)
  end

  def new_reservation_path_for_resource(resource)
    new_reservation_path(community: resource.community.abbrv.downcase, resource_id: resource.id)
  end
end
module ReservationsHelper
  def reservations_path_for_resource(resource)
    reservations_path(community: resource.community.abbrv.downcase, resource_id: resource.id)
  end

  def new_reservation_path_for_resource(resource)
    new_reservation_path(community: resource.community.abbrv.downcase, resource_id: resource.id)
  end
end

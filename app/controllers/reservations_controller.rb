class ReservationsController < ApplicationController
  def index
    authorize Reservation::Reservation
    @reservations = policy_scope(Reservation::Reservation)
  end

  def new
    @resource = Reservation::Resource.find(params[:resource])
    raise "Resource not found" unless @resource

    @reservation = Reservation::Reservation.new_with_defaults(@resource)
    authorize @reservation

    @kinds = @resource.kinds # May be nil
  end
end

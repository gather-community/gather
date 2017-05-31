module Reservation
  class ReservationDecorator < ApplicationDecorator
    delegate_all

    def location_name
      resource.decorate.name
    end
  end
end

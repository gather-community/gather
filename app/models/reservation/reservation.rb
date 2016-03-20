module Reservation
  class Reservation < ActiveRecord::Base
    self.table_name = "reservations"
  end
end
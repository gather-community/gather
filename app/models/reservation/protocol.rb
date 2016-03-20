module Reservation
  class Protocol < ActiveRecord::Base
    belongs_to :resource
  end
end

# Join class for Resource and Reservation::Protocol
module Reservation
  class Protocoling < ActiveRecord::Base
    belongs_to :protocol, class_name: "Reservation::Protocol"
    belongs_to :resource
  end
end

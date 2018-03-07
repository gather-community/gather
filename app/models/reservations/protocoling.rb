# Join class for Resource and Reservations::Protocol
module Reservations
  class Protocoling < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :protocol, class_name: "Reservations::Protocol"
    belongs_to :resource
  end
end

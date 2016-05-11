module Reservation
  class Resourcing < ActiveRecord::Base
    belongs_to :meal
    belongs_to :resource
  end
end

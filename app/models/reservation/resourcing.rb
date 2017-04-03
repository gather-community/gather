module Reservation
  class Resourcing < ActiveRecord::Base
    belongs_to :meal
    belongs_to :resource

    def resource=(r)
      association(:resource).writer(r)
      self.prep_time = r.community.settings.reservations.meals.default_prep_time
      self.total_time = r.community.settings.reservations.meals.default_total_time
    end
  end
end

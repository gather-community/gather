module Reservations
  class ResourceDecorator < ApplicationDecorator
    delegate_all

    def name
      "#{cmty_prefix_no_colon}#{object.name}"
    end

    def meal_abbrv
      "#{cmty_prefix_no_colon}#{object.meal_abbrv}"
    end
  end
end

module Reservations
  class ResourceDecorator < ApplicationDecorator
    delegate_all

    def name_with_prefix
      "#{cmty_prefix_no_colon}#{name}"
    end

    def meal_abbrv
      "#{cmty_prefix_no_colon}#{object.meal_abbrv}"
    end
  end
end

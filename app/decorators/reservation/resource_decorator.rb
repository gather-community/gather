module Reservation
  class ResourceDecorator < ApplicationDecorator
    delegate_all

    def name
      prefix = h.multi_community? ? "#{community.abbrv}: " : ""
      "#{prefix}#{object.name}"
    end
  end
end

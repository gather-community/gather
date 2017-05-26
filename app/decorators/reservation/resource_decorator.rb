module Reservation
  class ResourceDecorator < Draper::Decorator
    delegate_all

    def name
      prefix = h.multi_community? ? "#{community.abbrv}: " : ""
      "#{prefix}#{object.name}"
    end
  end
end

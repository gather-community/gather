module Reservations
  class ResourceDecorator < ApplicationDecorator
    delegate_all

    def name_with_prefix
      "#{cmty_prefix_no_colon}#{name}"
    end

    def abbrv_with_prefix
      "#{cmty_prefix_no_colon}#{abbrv}"
    end
  end
end

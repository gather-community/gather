module Reservations
  class ReservationDecorator < ApplicationDecorator
    delegate_all

    delegate :pre_notice?, to: :rule_set

    def pre_notice
      h.safe_render_markdown(rule_set.pre_notice)
    end

    def location_name
      resource.decorate.name
    end
  end
end

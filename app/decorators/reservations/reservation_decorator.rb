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

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_reservation_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.reservation_path(object),
          method: :delete, confirm: {name: name})
      )
    end
  end
end

module Reservations
  class ResourceDecorator < ApplicationDecorator
    delegate_all

    def name_with_prefix
      "#{cmty_prefix_no_colon}#{name}"
    end

    def name_with_inactive
      "#{name}#{active? ? "" : " (Inactive)"}"
    end

    def abbrv_with_prefix
      "#{cmty_prefix_no_colon}#{abbrv}"
    end

    def tr_classes
      active? ? "" : "inactive"
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle",
          path: h.deactivate_reservations_resource_path(object), method: :put, confirm: {name: name}),
        ActionLink.new(object, :destroy, icon: "trash", path: h.reservations_resource_path(object),
          method: :delete, confirm: {name: name})
      )
    end
  end
end

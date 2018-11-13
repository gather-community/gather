# frozen_string_literal: true

module Reservations
  class ResourceDecorator < ApplicationDecorator
    delegate_all

    def name_with_prefix
      "#{cmty_prefix_no_colon}#{name}"
    end

    def name_with_inactive
      "#{name}#{active? ? '' : ' (Inactive)'}"
    end

    def abbrv_with_prefix
      "#{cmty_prefix_no_colon}#{abbrv}"
    end

    def tr_classes
      active? ? "" : "inactive"
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", method: :put, confirm: {name: name},
                                            path: h.deactivate_reservations_resource_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", method: :delete, confirm: {name: name},
                                         path: h.reservations_resource_path(object))
      )
    end
  end
end

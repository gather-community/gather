# frozen_string_literal: true

module Meals
  class TypeDecorator < ApplicationDecorator
    delegate_all

    def tr_classes
      active? ? "" : "inactive"
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", path: h.deactivate_meals_type_path(object),
                                            method: :put, confirm: {name: name}),
        ActionLink.new(object, :destroy, icon: "trash", path: h.meals_type_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end
  end
end

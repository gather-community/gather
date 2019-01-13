# frozen_string_literal: true

module Meals
  class RoleDecorator < ApplicationDecorator
    delegate_all

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.meals_role_path(object),
                                         method: :delete, confirm: {title: title})
      )
    end
  end
end

# frozen_string_literal: true

module Meals
  class RoleDecorator < ApplicationDecorator
    delegate_all

    def title_with_suffix
      safe_str.tap do |str|
        str << title
        str << " (#{t('common.inactive')})" if inactive?
      end
    end

    def tr_classes
      active? ? "" : "inactive"
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", path: h.deactivate_meals_role_path(object),
                                            method: :put, confirm: {title: title}),
        ActionLink.new(object, :destroy, icon: "trash", path: h.meals_role_path(object),
                                         method: :delete, confirm: {title: title})
      )
    end
  end
end

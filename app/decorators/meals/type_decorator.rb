# frozen_string_literal: true

module Meals
  class TypeDecorator < ApplicationDecorator
    delegate_all

    def name_with_suffix
      safe_str.tap do |str|
        str << name
        str << " (#{t('common.inactive')})" if inactive?
      end
    end

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

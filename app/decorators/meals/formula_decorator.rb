module Meals
  class FormulaDecorator < ApplicationDecorator
    delegate_all

    def name_with_suffix
      "".html_safe.tap do |str|
        str << name
        str << " (#{t("common.default")})" if is_default?
        str << " (#{t("common.inactive")})" if inactive?
      end
    end

    def pantry_fee_formatted
      if fixed_pantry?
        h.number_to_currency(pantry_fee)
      else
        decimal_to_percentage(pantry_fee)
      end
    end

    def created_on
      I18n.l(created_at, format: :full_date)
    end

    def tr_classes
      active? ? "" : "inactive"
    end

    def role_titles
      roles.decorate.map(&:title_with_suffix).join(", ")
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_meals_formula_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", path: h.deactivate_meals_formula_path(object),
          method: :put, confirm: {name: name}),
        ActionLink.new(object, :destroy, icon: "trash", path: h.meals_formula_path(object),
          method: :delete, confirm: {name: name})
      )
    end
  end
end

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

    def signup_type_count
      "".html_safe.tap do |str|
        str << allowed_signup_types[0..1].map { |st| t("signups.types.#{st}") }.join(", ")
        if allowed_signup_types.size > 2
          str << ", ... ("
          str << t("common.num_in_total", count: allowed_signup_types.size)
          str << ")"
        end
      end
    end

    def pantry_fee_nice
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

    Signup::SIGNUP_TYPES.each do |st|
      define_method("#{st}_nice") do
        if fixed_meal?
          h.number_to_currency(object[st])
        else
          decimal_to_percentage(object[st])
        end
      end
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

    private

    def decimal_to_percentage(num)
      h.number_to_percentage(num.try(:*, 100), precision: 1)
    end
  end
end

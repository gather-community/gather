module Meals
  class FormulaDecorator < ApplicationDecorator
    delegate_all

    def name_with_default
      "".html_safe.tap do |str|
        str << name
        str << " (#{t("common.default")})" if is_default?
      end
    end

    def meal_calc_type
      "".html_safe.tap do |str|
        str << t("meals/formulas.calc_types.#{object.meal_calc_type}")
        str << " (#{t("common.max")}: #{h.number_to_currency(max_cost)})" if fixed_meal?
      end
    end

    def pantry_calc_type
      "".html_safe.tap do |str|
        str << t("meals/formulas.calc_types.#{object.pantry_calc_type}")
        str << " ("
        str << (fixed_pantry? ? h.number_to_currency(pantry_fee) : h.number_to_percentage(pantry_fee))
        str << ")"
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

    def created_on
      I18n.l(created_at, format: :full_date)
    end

    def tr_classes
      active? ? "" : "inactive"
    end
  end
end

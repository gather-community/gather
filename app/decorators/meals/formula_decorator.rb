module Meals
  class FormulaDecorator < ApplicationDecorator
    delegate_all

    def name_with_default
      "".html_safe.tap do |str|
        str << name
        str << " (#{t("common.default")})" if is_default?
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

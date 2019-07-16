# frozen_string_literal: true

module Meals
  class CostDecorator < ApplicationDecorator
    delegate_all

    %i[ingredient_cost pantry_cost].each do |attrib|
      define_method("#{attrib}_formatted") do
        (num = self[attrib]).blank? ? "?" : h.number_to_currency(num)
      end

      define_method("#{attrib}_decimals") do
        (num = self[attrib]).blank? ? nil : h.number_with_precision(num, precision: 2)
      end
    end

    def payment_method_formatted
      t("simple_form.options.meals_meal.cost.payment_method.#{payment_method}")
    end
  end
end

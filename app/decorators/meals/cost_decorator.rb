# frozen_string_literal: true

module Meals
  class CostDecorator < ApplicationDecorator
    delegate_all

    def currency(item)
      num = self[:"#{item}_cost"]
      num.blank? ? "?" : h.number_to_currency(num)
    end

    def two_decimals(item)
      num = self[:"#{item}_cost"]
      num.blank? ? nil : h.number_with_precision(num, precision: 2)
    end

    def t_payment_method
      t("simple_form.options.meal.cost.payment_method.#{payment_method}")
    end
  end
end

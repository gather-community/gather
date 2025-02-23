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

    def payment_method_formatted_with_details(override = payment_method)
      parts = [t("simple_form.options.meals_meal.cost.payment_method.#{override}")]
      if override == "paypal" && paypal_email.present?
        parts << h.tag.span(paypal_email, id: "reimbursee-paypal-email")
      end
      h.safe_join(parts, " - ")
    end

    # Calculates price temporarily with given calculator if not yet calculated. Else just looks it up.
    def formatted_price_for_type(type:, calculator:)
      price = blank? ? calculator.price_for(type) : parts_by_type[type]&.value
      h.number_to_currency(price)
    end

    private

    def paypal_email
      reimbursee&.paypal_email_or_default
    end
  end
end

# frozen_string_literal: true

module Meals
  class FormulaPartDecorator < ApplicationDecorator
    delegate_all

    def share_formatted
      if fixed_meal?
        h.number_to_currency(share)
      else
        decimal_to_percentage(share)
      end
    end
  end
end

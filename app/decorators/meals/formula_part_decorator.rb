# frozen_string_literal: true

module Meals
  class FormulaPartDecorator < ApplicationDecorator
    delegate_all

    PORTION_SIZE_SELECT_OPTIONS = {full: 1.0, three_qtr: 0.75, half: 0.5, one_qtr: 0.25}.freeze

    def share_formatted
      if fixed_meal?
        h.number_to_currency(share)
      else
        decimal_to_percentage(share)
      end
    end

    def portion_size_select_options
      PORTION_SIZE_SELECT_OPTIONS.map { |n, p| [I18n.t("meals/formula_parts.portion_options.#{n}"), p.to_s] }
    end

    def portion_size_short_name
      key = PORTION_SIZE_SELECT_OPTIONS.each { |k, v| break k if (portion_size - v).abs < 0.01 }
      I18n.t("meals/formula_parts.portion_short_names.#{key}")
    end
  end
end

# frozen_string_literal: true

module Meals
  # Calculates meal cost according to the shared cost model.
  class ShareCostCalculator < CostCalculator
    def type
      :share
    end

    # Calculates the maximum amount the cook can spend on ingredients in order for
    # the meal to cost the given amount per adult.
    def max_ingredient_cost_for_full_price_of(full_price)
      if formula.fixed_pantry?
        full_price_equivs * (full_price - formula.pantry_fee)
      else
        full_price_equivs * full_price / (formula.pantry_fee + 1)
      end
    end

    protected

    def base_price_for(type)
      raise "ingredient_cost must be set to calculate base price" if meal.cost.ingredient_cost.blank?
      return 0 if full_price_equivs.zero?

      full_price = meal.cost.ingredient_cost / full_price_equivs
      share = formula.parts_by_type[type]&.share
      share ? share * full_price : nil
    end

    def full_price_equivs
      sum_product
    end
  end
end

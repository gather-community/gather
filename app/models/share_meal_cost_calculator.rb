class ShareMealCostCalculator < MealCostCalculator

  def type
    :share
  end

  # Calculates the maximum amount the cook can spend on ingredients in order for
  # the meal to cost the given amount per adult.
  def max_ingredient_cost_for_per_adult_cost(per_adult_cost)
    if formula.fixed_pantry?
      adult_equivs * (per_adult_cost - formula.pantry_fee)
    else
      adult_equivs * per_adult_cost / (formula.pantry_fee + 1)
    end
  end

  protected

  def base_price_for(signup_type)
    raise "ingredient_cost must be set to calculate base price" unless meal.ingredient_cost.present?
    return 0 if adult_equivs == 0
    per_adult_cost = meal.ingredient_cost / adult_equivs
    formula[signup_type] * per_adult_cost
  end

  def adult_equivs
    sum_product
  end
end

class ShareMealCostCalculator < MealCostCalculator

  def type
    :share
  end

  def max_ingredient_cost_for_per_adult_cost(per_adult_cost)
    per_adult_cost * adult_equivs
  end

  protected

  def base_price_for(signup_type)
    raise "ingredient_cost must be set to calculate base price" unless meal.ingredient_cost.present?
    per_adult_cost = meal.ingredient_cost / adult_equivs
    formula[signup_type] * per_adult_cost
  end

  def adult_equivs
    sum_product
  end
end
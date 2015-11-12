class FixedMealCostCalculator < MealCostCalculator

  def type
    :fixed
  end

  def max_grocery
    total_revenue - total_pantry
  end

  def base_price_for(signup_type)
    formula[signup_type]
  end

  def total_revenue
    sum_product
  end
end
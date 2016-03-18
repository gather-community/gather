class FixedMealCostCalculator < MealCostCalculator

  def type
    :fixed
  end

  def max_grocery
    sum_product
  end

  protected

  def base_price_for(signup_type)
    formula[signup_type]
  end
end
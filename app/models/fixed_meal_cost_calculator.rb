class FixedMealCostCalculator < MealCostCalculator

  def type
    :fixed
  end

  # Calculates the maximum the cook can spend on ingredients to stay within the
  # fixed maximum meal cost per person.
  def max_ingredient_cost
    sum_product
  end

  protected

  def base_price_for(signup_type)
    formula[signup_type]
  end
end
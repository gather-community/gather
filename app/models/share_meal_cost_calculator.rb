class ShareMealCostCalculator < MealCostCalculator

  def type
    :share
  end

  def max_grocery_for_per_adult_cost(per_adult_cost)
    if formula.fixed_pantry?
      per_adult_cost * adult_equivs - total_fixed_pantry
    else
      per_adult_cost * adult_equivs / (1 + formula.pantry_fee)
    end
  end

  def adult_equivs
    sum_product
  end
end
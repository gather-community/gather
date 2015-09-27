class FixedMealCostCalculator < MealCostCalculator

  def type
    :fixed
  end

  def max_grocery
    total_revenue - total_pantry
  end

  def total_revenue
    sum_product
  end

  def total_pantry
    @total_patry ||= if formula.fixed_pantry?
      total_fixed_pantry
    else
      total_revenue - (total_revenue / (1 + formula.pantry_fee))
    end
  end
end
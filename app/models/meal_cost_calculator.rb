class MealCostCalculator
  attr_accessor :meal, :formula, :prices

  def self.build(meal)
    formula = Formula.for_meal(meal)
    case formula.meal_calc_type
    when "fixed" then FixedMealCostCalculator.new(meal, formula)
    when "share" then ShareMealCostCalculator.new(meal, formula)
    else raise "Unknown meal calc type"
    end
  end

  def initialize(meal, formula)
    self.meal = meal
    self.formula = formula
    self.prices = {}
  end

  def type
    raise NotImplementedError
  end

  def price_for(signup_type)
    return prices[signup_type] if prices[signup_type].present?
    base_price = base_price_for(signup_type)
    self.prices[signup_type] = base_price + pantry_fee_for(base_price)
  end

  def pantry_fee_for(base_price)
    return 0 if base_price < 0.01
    if formula.fixed_pantry?
      formula.pantry_fee
    else
      formula.pantry_fee * base_price
    end
  end

  def total_pantry
    @total_patry ||= if formula.fixed_pantry?
      total_fixed_pantry
    else
      total_revenue - (total_revenue / (1 + formula.pantry_fee))
    end
  end

  def total_fixed_pantry
    # Fixed fee for everyone except those with zero meal costs.
    Signup.totals_for_meal(meal).map do |signup_type, count|
      formula[signup_type] == 0 ? 0 : formula.pantry_fee * count
    end.reduce(:+)
  end

  def sum_product
    @total_revenue ||= Signup.totals_for_meal(meal).map do |signup_type, count|
      (formula[signup_type] || 0) * count
    end.reduce(:+)
  end
end

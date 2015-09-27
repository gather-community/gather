class MealCostCalculator
  attr_accessor :meal, :formula

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
  end

  def type
    raise NotImplementedError
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

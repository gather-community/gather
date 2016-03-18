class MealCostCalculator

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

  protected

  attr_accessor :meal, :formula, :prices

  def sum_product
    @sum_product ||= Signup.totals_for_meal(meal).map do |signup_type, count|
      (formula[signup_type] || 0) * count
    end.reduce(:+)
  end

  private

  def pantry_fee_for(base_price)
    return 0 if base_price < 0.01
    if formula.fixed_pantry?
      formula.pantry_fee
    else
      formula.pantry_fee * base_price
    end
  end

end

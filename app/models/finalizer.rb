# Finalizes meals
class Finalizer
  attr_accessor :meal

  def initialize(meal)
    self.meal = meal
  end

  # Takes numbers of each diner type, computes cost for each diner type based on formulas,
  # and create line items.
  def finalize!
    calculator = MealCostCalculator.build(meal)

    meal.signups.each do |signup|
      meal.allowed_signup_types.each do |signup_type|
        next if signup[signup_type] == 0

        price = calculator.price_for(signup_type)
        next if price < 0.01

        LineItem.create!(
          account: Account.for(signup.household_id, meal.host_community_id),
          code: "meal",
          incurred_on: meal.served_at.to_date,
          description: "#{meal.title}: #{I18n.t('signups.types.' << signup_type)}",
          quantity: signup[signup_type],
          unit_price: price
        )
     end
    end
  end
end

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

        Transaction.create!(
          account: Account.for(signup.household_id, meal.host_community_id),
          code: "meal",
          incurred_on: meal.served_at.to_date,
          description: "#{meal.title}: #{I18n.t('signups.types.' << signup_type)}",
          quantity: signup[signup_type],
          unit_price: price,
          statementable: meal
        )
     end
    end

    if meal.payment_method == "credit"
      Transaction.create!(
        account: Account.for(meal.head_cook.household_id, meal.host_community_id),
        code: "reimb",
        incurred_on: meal.served_at.to_date,
        description: "#{meal.title}: Grocery Reimbursement",
        amount: -(meal.ingredient_cost + meal.pantry_cost),
        statementable: meal
      )
    end
  end
end

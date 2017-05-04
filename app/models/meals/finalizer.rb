# Finalizes meals
module Meals
  class Finalizer
    attr_accessor :meal, :meal_cost

    delegate :signups, to: :meal

    def initialize(meal)
      self.meal = meal
      self.meal_cost = meal.cost
    end

    # Takes numbers of each diner type, computes cost for each diner type based on formulas,
    # and create line items.
    # Assumes that meal is valid and ready to be saved.
    def finalize!
      create_diner_transactions
      create_reimbursement_transaction
      copy_meal_costs
      meal.status = "finalized"
      meal.save!
    end

    private

    def create_diner_transactions
      signups.each do |signup|
        meal.allowed_signup_types.each do |signup_type|
          next if signup[signup_type] == 0

          price = calculator.price_for(signup_type)
          next if price < 0.01

          Billing::Transaction.create!(
            account: Billing::Account.for(signup.household_id, meal.community_id),
            code: "meal",
            incurred_on: meal.served_at.to_date,
            description: "#{meal.title}: #{I18n.t('signups.types.' << signup_type)}",
            quantity: signup[signup_type],
            unit_price: price,
            statementable: meal
          )
        end
      end
    end

    def create_reimbursement_transaction
      if meal_cost.payment_method == "credit" && meal_cost.total_cost > 0
        Billing::Transaction.create!(
          account: Billing::Account.for(meal.head_cook.household_id, meal.community_id),
          code: "reimb",
          incurred_on: meal.served_at.to_date,
          description: "#{meal.title}: Grocery Reimbursement",
          amount: -(meal_cost.total_cost),
          statementable: meal
        )
      end
    end

    def copy_meal_costs
      attribs = {}
      meal.allowed_signup_types.each { |st| attribs[st] = calculator.price_for(st) }
      %i(meal_calc_type pantry_calc_type pantry_fee).each { |a| attribs[a] = calculator.send(a) }
      meal_cost.update_attributes!(attribs)
    end

    def calculator
      @calculator ||= MealCostCalculator.build(meal)
    end
  end
end

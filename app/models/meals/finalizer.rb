# frozen_string_literal: true

module Meals
  # Finalizes meals and creates transactions.
  class Finalizer
    attr_accessor :meal, :cost

    delegate :signups, to: :meal

    def initialize(meal)
      self.meal = meal
      self.cost = meal.cost
    end

    # Takes numbers of each diner type, computes cost for each diner type based on formulas,
    # and create line items.
    def finalize!
      create_diner_transactions
      create_reimbursement_transaction
      copy_prices
    end

    def unfinalize!
      # This should not be possible since calls to this method should be guarded by the
      # policy, but just in case!
      if meal.transactions.any?(&:statement?)
        raise "Can't unfinalize meal with transactions on statements"
      end

      meal.transactions.destroy_all
      if cost
        %i[meal_calc_type pantry_calc_type pantry_fee].each { |a| cost[a] = nil }
        cost.save!
        cost.parts.destroy_all
      end
      meal.close!
    end

    def calculator
      @calculator ||= CostCalculator.build(meal)
    end

    private

    def create_diner_transactions
      signups.each do |signup|
        next if signup.marked_for_destruction?
        signup.parts.each { |p| create_diner_transaction(signup_part: p) }
      end
    end

    def create_diner_transaction(signup_part:)
      return if signup_part.count.zero?
      price = calculator.price_for(signup_part.type)
      return if price < 0.01

      Billing::Transaction.create!(
        account: Billing::AccountManager.instance.account_for(household_id: signup_part.household_id,
          community_id: meal.community_id),
        code: "meal",
        incurred_on: meal.served_at.to_date,
        description: "#{meal.title}: #{signup_part.type_name}",
        quantity: signup_part.count,
        unit_price: price,
        statementable: meal
      )
    end

    def create_reimbursement_transaction
      return unless cost.payment_method == "credit" && cost.total_cost.positive?

      # This shouldn't happen but we couldn't put a null false constraint on the column due to legacy data.
      raise ArgumentError, "Meal ##{meal.id} cost has no reimbursee" if cost.reimbursee.nil?

      Billing::Transaction.create!(
        account: Billing::AccountManager.instance.account_for(household_id: cost.reimbursee.household_id,
          community_id: meal.community_id),
        code: "reimb",
        incurred_on: meal.served_at.to_date,
        description: "#{meal.title}: Grocery Reimbursement",
        value: cost.total_cost,
        statementable: meal
      )
    end

    def copy_prices
      attribs = {}
      %i[meal_calc_type pantry_calc_type pantry_fee].each { |a| attribs[a] = calculator.send(a) }
      cost.update!(attribs)
      meal.types.each { |type| cost.parts.create!(type: type, value: calculator.price_for(type)) }
    end
  end
end

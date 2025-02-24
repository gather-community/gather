# frozen_string_literal: true

module Meals
  # Calculates the per-person cost of a given meal.
  class CostCalculator
    delegate :meal_calc_type, :pantry_calc_type, :pantry_fee, to: :formula

    def self.build(meal)
      case meal.formula.meal_calc_type
      when "fixed" then FixedCostCalculator.new(meal)
      when "share" then ShareCostCalculator.new(meal)
      else raise "Unknown meal calc type"
      end
    end

    def initialize(meal)
      self.meal = meal
      self.formula = meal.formula
      self.prices = {}
    end

    def type
      raise NotImplementedError
    end

    # Returns a price for the given signup type, rounded to the nearest cent.
    def price_for(type)
      return prices[type] if prices.key?(type)

      base_price = base_price_for(type)
      prices[type] = base_price ? (base_price + pantry_fee_for(base_price)).round(2) : nil
    end

    protected

    attr_accessor :meal, :formula, :prices

    def sum_product
      @sum_product ||= meal.signup_totals.map do |type, count|
        (formula.parts_by_type[type]&.share || 0) * count
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
end

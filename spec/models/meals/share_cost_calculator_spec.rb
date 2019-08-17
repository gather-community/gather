# frozen_string_literal: true

require "rails_helper"

describe Meals::ShareCostCalculator do
  let(:formula) do
    create(:meal_formula, meal_calc_type: "share", pantry_calc_type: pantry_calc_type,
                          pantry_fee: pantry_fee, parts_attrs: %w[100% 75% 0])
  end
  let(:types) { formula.types }
  let(:meal) { build(:meal, formula: formula) }
  let(:calculator) { Meals::ShareCostCalculator.new(meal) }

  before do
    meal.build_cost
    # 11.25 adult equivalents
    allow(meal).to receive(:signup_totals).and_return(types[0] => 9, types[1] => 3, types[2] => 2)
  end

  context "with regular meal" do
    before { meal.cost = build(:meal_cost, meal: meal, ingredient_cost: 100, pantry_cost: 15) }

    context "with fixed pantry_calc_type" do
      let(:pantry_calc_type) { "fixed" }
      let(:pantry_fee) { 0.5 }

      describe "price_for" do
        it "should be correct" do
          expect(calculator.price_for(types[0])).to be_within(0.005).of(9.39)
          expect(calculator.price_for(types[1])).to be_within(0.005).of(7.17)
          expect(calculator.price_for(types[2])).to be_zero
        end
      end

      describe "max_ingredient_cost_for_full_price_of_zzz" do
        it "should be correct" do
          # 7.00 = (ingredient_cost / full_price) + 0.50
          # 6.50 * full_price = ingredient_cost
          expect(calculator.max_ingredient_cost_for_full_price_of_zzz(7)).to be_within(0.005).of(73.13)
          expect(calculator.max_ingredient_cost_for_full_price_of_zzz(8)).to be_within(0.005).of(84.38)
        end
      end
    end

    context "with ratio pantry_calc_type" do
      let(:pantry_calc_type) { "ratio" }
      let(:pantry_fee) { 0.1 }

      describe "price_for" do
        it "should be correct" do
          expect(calculator.price_for(types[0])).to be_within(0.005).of(9.78)
          expect(calculator.price_for(types[1])).to be_within(0.005).of(7.33)
          expect(calculator.price_for(types[2])).to be_zero
        end
      end

      describe "max_ingredient_cost_for_full_price_of_zzz" do
        it "should be correct for target price of 4.50" do
          # 4.50 = (ingredient_cost / full_price) * 1.1
          # (4.50 / 1.1) * full_price = ingredient_cost
          expect(calculator.max_ingredient_cost_for_full_price_of_zzz(4.50)).to be_within(0.005).of(46.02)
          expect(calculator.max_ingredient_cost_for_full_price_of_zzz(3.50)).to be_within(0.005).of(35.80)
        end
      end
    end
  end

  context "with zero dollar ingredient and zero signup meal" do
    let(:pantry_calc_type) { "fixed" }
    let(:pantry_fee) { 0.5 }
    before { meal.cost = build(:meal_cost, meal: meal, ingredient_cost: 0, pantry_cost: 15) }

    before do
      allow(meal).to receive(:signup_totals).and_return(types[0] => 0)
    end

    describe "price_for" do
      it "should be zero" do
        expect(calculator.price_for(types[0])).to be_zero
      end
    end
  end
end

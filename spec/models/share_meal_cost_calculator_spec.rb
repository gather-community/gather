require "rails_helper"

describe Meals::ShareCostCalculator do

  let(:formula) do
    build(:meal_formula,
      meal_calc_type: "share",
      pantry_calc_type: pantry_calc_type,
      pantry_fee: pantry_fee,
      adult_meat: 1,
      adult_veg: 0.75,
      little_kid_veg: 0
    )
  end
  let(:meal) { build(:meal, formula: formula) }
  let(:calculator) { Meals::ShareCostCalculator.new(meal) }

  before do
    meal.build_cost
    allow(Signup).to receive(:totals_for_meal).and_return(
      "adult_meat" => 9, "adult_veg" => 3, "little_kid_veg" => 2 # 11.25 adult equivalents
    )
  end

  context "with regular meal" do
    before { meal.cost = build(:meal_cost, ingredient_cost: 100, pantry_cost: 15) }

    context "with fixed pantry_calc_type" do
      let(:pantry_calc_type) { "fixed" }
      let(:pantry_fee) { 0.5 }

      describe "price_for" do
        it "should be correct" do
          expect(calculator.price_for("adult_meat")).to be_within(0.005).of(9.39)
          expect(calculator.price_for("adult_veg")).to be_within(0.005).of(7.17)
          expect(calculator.price_for("little_kid_veg")).to eq 0
        end
      end

      describe "max_ingredient_cost_for_per_adult_cost" do
        it "should be correct" do
          # 7.00 = (ingredient_cost / adult_equivs) + 0.50
          # 6.50 * adult_equivs = ingredient_cost
          expect(calculator.max_ingredient_cost_for_per_adult_cost(7)).to be_within(0.005).of(73.13)
          expect(calculator.max_ingredient_cost_for_per_adult_cost(8)).to be_within(0.005).of(84.38)
        end
      end
    end

    context "with ratio pantry_calc_type" do
      let(:pantry_calc_type) { "ratio" }
      let(:pantry_fee) { 0.1 }

      describe "price_for" do
        it "should be correct" do
          expect(calculator.price_for("adult_meat")).to be_within(0.005).of(9.78)
          expect(calculator.price_for("adult_veg")).to be_within(0.005).of(7.33)
          expect(calculator.price_for("little_kid_veg")).to eq 0
        end
      end

      describe "max_ingredient_cost_for_per_adult_cost" do
        it "should be correct for target price of 4.50" do
          # 4.50 = (ingredient_cost / adult_equivs) * 1.1
          # (4.50 / 1.1) * adult_equivs = ingredient_cost
          expect(calculator.max_ingredient_cost_for_per_adult_cost(4.50)).to be_within(0.005).of(46.02)
          expect(calculator.max_ingredient_cost_for_per_adult_cost(3.50)).to be_within(0.005).of(35.80)
        end
      end
    end
  end

  context "with zero dollar ingredient and zero signup meal" do
    let(:pantry_calc_type) { "fixed" }
    let(:pantry_fee) { 0.5 }
    before { meal.cost = build(:meal_cost, ingredient_cost: 0, pantry_cost: 15) }

    before do
      allow(Signup).to receive(:totals_for_meal).and_return("adult_meat" => 0)
    end

    describe "price_for" do
      it "should be zero" do
        expect(calculator.price_for("adult_meat")).to eq 0
      end
    end
  end
end

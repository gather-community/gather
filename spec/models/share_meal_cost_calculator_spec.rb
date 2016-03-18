require 'rails_helper'

RSpec.describe ShareMealCostCalculator, type: :model do

  let(:formula) do
    build(:formula,
      meal_calc_type: "share",
      pantry_calc_type: pantry_calc_type,
      pantry_fee: pantry_fee,
      adult_meat: 1,
      adult_veg: 0.75,
      little_kid_veg: 0
    )
  end
  let(:meal) { build(:meal, ingredient_cost: 100, pantry_cost: 15) }
  let(:calculator) { ShareMealCostCalculator.new(meal, formula) }

  before do
    allow(Signup).to receive(:totals_for_meal).and_return(
      "adult_meat" => 9, "adult_veg" => 3, "little_kid_veg" => 2
    )
  end

  context "with fixed pantry_calc_type" do
    let(:pantry_calc_type) { "fixed" }
    let(:pantry_fee) { 0.5 }

    describe "price_for" do
      it "should be correct" do
        expect(calculator.price_for("adult_meat")).to be_within(0.001).of(9.389)
        expect(calculator.price_for("adult_veg")).to be_within(0.001).of(7.167)
        expect(calculator.price_for("little_kid_veg")).to eq 0
      end
    end

    describe "max_grocery_for_per_adult_cost" do
      it "should be correct" do
        expect(calculator.max_grocery_for_per_adult_cost(7)).to be_within(0.001).of(78.75)
        expect(calculator.max_grocery_for_per_adult_cost(8)).to be_within(0.001).of(90)
      end
    end
  end

  context "with ratio pantry_calc_type" do
    let(:pantry_calc_type) { "ratio" }
    let(:pantry_fee) { 0.1 }

    describe "price_for" do
      it "should be correct" do
        expect(calculator.price_for("adult_meat")).to be_within(0.001).of(9.777)
        expect(calculator.price_for("adult_veg")).to be_within(0.001).of(7.333)
        expect(calculator.price_for("little_kid_veg")).to eq 0
      end
    end
  end
end

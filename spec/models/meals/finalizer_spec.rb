# frozen_string_literal: true

require "rails_helper"

describe Meals::Finalizer do
  let(:formula) { create(:meal_formula, parts_attrs: [{type: "Adult"}, {type: "Teen"}, {type: "Kid"}]) }
  let(:meal) do
    create(:meal, :with_menu,
           formula: formula,
           cost_attributes: {ingredient_cost: 20.23, pantry_cost: 5.11, payment_method: "credit"})
  end
  let(:households) { create_list(:household, 2) }
  let(:finalizer) { Meals::Finalizer.new(meal) }
  let!(:signups) do
    [create(:meal_signup, meal: meal, household: households[0], diner_counts: [2, 0, 0]),
     create(:meal_signup, meal: meal, household: households[1], diner_counts: [0, 1, 1])]
  end
  let(:txns_by_household) { Billing::Transaction.all.to_a.index_by(&:household_id) }
  let(:cost) { Meals::Cost.first }

  before do
    calculator = double
    allow(finalizer).to receive(:signups).and_return(signups)
    allow(finalizer).to receive(:calculator).and_return(calculator)
    allow(calculator).to receive(:price_for).and_return(4.56, 1.23, 0, 4.56, 1.23, 0) # Called from two loops
    allow(calculator).to receive(:meal_calc_type).and_return("fixed")
    allow(calculator).to receive(:pantry_calc_type).and_return("ratio")
    allow(calculator).to receive(:pantry_fee).and_return(0.1) # 10%
    finalizer.finalize!
  end

  it "creates the appropriate transactions" do
    expect(txns_by_household.size).to eq(3)
    expect(txns_by_household[households[0].id]).to have_attributes(
      code: "meal",
      description: "#{meal.title}: Adult",
      incurred_on: meal.served_at.to_date,
      quantity: 2,
      unit_price: 4.56,
      statementable: meal
    )
    expect(txns_by_household[households[1].id]).to have_attributes(
      code: "meal",
      description: "#{meal.title}: Teen",
      incurred_on: meal.served_at.to_date,
      quantity: 1,
      unit_price: 1.23,
      statementable: meal
    )
    expect(txns_by_household[meal.head_cook.household_id]).to have_attributes(
      code: "reimb",
      description: "#{meal.title}: Grocery Reimbursement",
      incurred_on: meal.served_at.to_date,
      amount: -25.34,
      statementable: meal
    )
  end

  it "copies meal costs to MealCost model" do
    expect(Meals::Cost.count).to eq(1)
    expect(cost).to have_attributes(meal: meal, meal_calc_type: "fixed", pantry_calc_type: "ratio")
    expect(cost.ingredient_cost).to be_within(0.001).of(20.23)
    expect(cost.pantry_cost).to be_within(0.001).of(5.11)
    expect(cost.pantry_fee).to be_within(0.001).of(0.1)
    expect(cost.parts.count).to eq(3)
    expect(cost.parts.map(&:type)).to eq(formula.types)
    expect(cost.parts[0].value).to be_within(0.001).of(4.56)
    expect(cost.parts[1].value).to be_within(0.001).of(1.23)
    expect(cost.parts[2].value).to be_within(0.001).of(0)
  end
end

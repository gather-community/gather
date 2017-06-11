require 'rails_helper'

RSpec.describe Meals::Finalizer, type: :model do
  let(:meal) { create(:meal, :with_menu,
    cost_attributes: {ingredient_cost: 20.23, pantry_cost: 5.11, payment_method: "credit"}) }
  let(:households) { create_list(:household, 2) }
  let(:formula) { create(:meals_formula) }
  let(:finalizer) { Meals::Finalizer.new(meal) }

  before do
    signups = [
      meal.signups.create!(adult_meat: 2, household: households[0]),
      meal.signups.create!(senior_veg: 1, little_kid_meat: 1, household: households[1])
    ]

    calculator = double
    allow(meal).to receive(:allowed_signup_types).and_return(%w(adult_meat senior_veg little_kid_meat))
    allow(finalizer).to receive(:signups).and_return(signups)
    allow(finalizer).to receive(:calculator).and_return(calculator)
    allow(calculator).to receive(:price_for).and_return(4.56, 1.23, 0, 4.56, 1.23, 0) # Called from two loops
    allow(calculator).to receive(:meal_calc_type).and_return("fixed")
    allow(calculator).to receive(:pantry_calc_type).and_return("ratio")
    allow(calculator).to receive(:pantry_fee).and_return(0.1) # 10%

    finalizer.finalize!
  end

  it "creates the appropriate transactions" do
    txs = Billing::Transaction.all.to_a.index_by(&:household_id)

    expect(txs.size).to eq 3

    expect(txs[households[0].id]).to have_attributes(
      code: "meal",
      description: "#{meal.title}: Adult (Meat)",
      incurred_on: meal.served_at.to_date,
      quantity: 2,
      unit_price: 4.56,
      statementable: meal
    )

    expect(txs[households[1].id]).to have_attributes(
      code: "meal",
      description: "#{meal.title}: Senior (Veg)",
      incurred_on: meal.served_at.to_date,
      quantity: 1,
      unit_price: 1.23,
      statementable: meal
    )

    expect(txs[meal.head_cook.household_id]).to have_attributes(
      code: "reimb",
      description: "#{meal.title}: Grocery Reimbursement",
      incurred_on: meal.served_at.to_date,
      amount: -25.34,
      statementable: meal
    )
  end

  it "copies meal costs to MealCost model" do
    mcs = Meals::Cost.all.to_a
    expect(mcs.size).to eq 1
    expect(mcs.first).to have_attributes(
      meal: meal,
      adult_meat: 4.56,
      senior_veg: 1.23,
      little_kid_meat: 0,
      adult_veg: nil, # Non-allowed signup types should be nil
      ingredient_cost: 20.23,
      pantry_cost: 5.11,
      meal_calc_type: "fixed",
      pantry_calc_type: "ratio",
      pantry_fee: 0.1
    )
  end

  it "sets meal to finalized" do
    expect(meal.status).to eq "finalized"
  end
end

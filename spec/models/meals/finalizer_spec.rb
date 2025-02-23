# frozen_string_literal: true

require "rails_helper"

describe Meals::Finalizer do
  let(:formula) { create(:meal_formula, parts_attrs: [{type: "Adult"}, {type: "Teen"}, {type: "Kid"}]) }
  let(:reimbursee) { create(:user) }
  let(:meal) do
    create(:meal, :with_menu,
           formula: formula,
           cost_attributes: {ingredient_cost: 20.23, pantry_cost: 5.11,
                             payment_method: "credit", reimbursee_id: reimbursee.id})
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
  end

  describe "finalize!" do
    it "creates the appropriate transactions" do
      finalizer.finalize!
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
      expect(txns_by_household[reimbursee.household_id]).to have_attributes(
        code: "reimb",
        description: "#{meal.title}: Grocery Reimbursement",
        incurred_on: meal.served_at.to_date,
        value: 25.34,
        statementable: meal
      )
    end

    it "copies meal costs to MealCost model" do
      finalizer.finalize!
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

    context "with no reimbursee" do
      before do
        meal.cost.update_attribute(:reimbursee_id, nil)
      end

      it "raises error" do
        expect { finalizer.finalize! }.to raise_error(ArgumentError)
      end
    end
  end

  describe "unfinalize!" do
    # Use a separate meal reference and finalizer as this is truer to real operation
    let(:meal_ref_2) { Meals::Meal.find(meal.id) }
    let(:finalizer2) { Meals::Finalizer.new(meal) }

    before do
      finalizer.finalize!
    end

    it "deletes transactions, nils cost fields, deletes cost parts, updates status" do
      finalizer2.unfinalize!

      expect(meal_ref_2.transactions).to be_empty
      expect(meal_ref_2.cost.meal_calc_type).to be_nil
      expect(meal_ref_2.cost.pantry_calc_type).to be_nil
      expect(meal_ref_2.cost.pantry_fee).to be_nil
      expect(meal_ref_2.cost.parts).to be_empty
      expect(meal_ref_2).to be_closed
    end

    context "with transactions with statements" do
      before do
        meal_ref_2.transactions.first.update!(statement: create(:statement))
      end

      it "raises error" do
        expect do
          finalizer2.unfinalize!
        end.to raise_error("Can't unfinalize meal with transactions on statements")
      end
    end
  end
end

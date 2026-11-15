# frozen_string_literal: true

require "rails_helper"

describe Meals::MealCsvExporter do
  let(:community) { Defaults.community }
  let(:policy) { Meals::MealPolicy.new(actor, Meals::Meal.new(community: community)) }
  let(:exporter) do
    described_class.new(Meals::Meal.hosted_by(community).oldest_first, policy: policy,
      community: community)
  end

  describe "to_csv" do
    context "with no meals" do
      let(:actor) { create(:meals_coordinator) }

      it "returns valid csv" do
        # Full headers are tested below.
        expect(exporter.to_csv).to match(%r{\ADate/Time,Locations,Formula,})
      end
    end

    context "with meals" do
      let(:actor) { create(:meals_coordinator, first_name: "Cora", last_name: "Dinator") }
      let!(:other_community) { create(:community, name: "Bravo", abbrv: "BV") }
      let!(:calendar) { create(:calendar, name: "Dining Room", meal_hostable: true) }
      let!(:formula) do
        create(:meal_formula, :with_two_roles, name: "Standard",
          parts_attrs: [{type: "Adult", share: "100%"}, {type: "Teen", share: "75%"}])
      end

      # Active in the community but not part of the formula, so its columns should be blank.
      let!(:unused_type) { create(:meal_type, name: "Senior", category: "Meat") }

      # Neither of these should get a column.
      let!(:inactive_type) { create(:meal_type, name: "Retired Type", deactivated_at: Time.current - 1) }
      let!(:inactive_role) { create(:meal_role, :inactive, title: "Retired Role") }

      let!(:head_cook) { create(:user, first_name: "Jo", last_name: "Cook") }
      let!(:asst_cook) { create(:user, first_name: "Al", last_name: "Helper") }
      let!(:households) do
        [create(:household, name: "Smith"), create(:household, name: "Li")]
      end

      # Deliberately created out of order to ensure the sort is respected.
      let!(:meal2) do
        create(:meal, :with_menu, formula: formula, calendars: [calendar], community: community,
          communities: [community, other_community], served_at: "2018-11-05 18:00",
          head_cook: head_cook, asst_cooks: [asst_cook], title: "Tacos", entrees: "Tacos al pastor",
          side: "Rice", kids: "Quesadillas", dessert: "Flan", notes: "Bring a plate",
          allergens: %w[Dairy Soy], capacity: 60)
      end
      let!(:meal1) do
        create(:meal, :with_menu, formula: formula, calendars: [calendar], community: community,
          communities: [community], served_at: "2018-10-15 18:00", head_cook: head_cook,
          title: "Stew", entrees: "Beef stew", allergens: [], no_allergens: true, capacity: 50,
          status: "finalized")
      end

      before do
        Timecop.freeze("2018-11-01 12:00") do
          create(:meal_signup, meal: meal2, household: households[0], diner_counts: [2, 1])
          create(:meal_signup, meal: meal2, household: households[1], diner_counts: [1, 0],
            takeout: true, comments: "No onions, please")
        end
        # Built by hand rather than via the :meal_cost factory, which would create a second meal.
        cost = Meals::Cost.new(meal: meal1, ingredient_cost: 84.50, pantry_cost: 8.45,
          payment_method: "paypal", reimbursee: head_cook)
        formula.types.each_with_index { |type, i| cost.parts.build(type: type, value: 4.25 - i) }
        cost.save!
      end

      it "returns valid csv" do
        expect(exporter.to_csv).to eq(prepare_fixture("meals/meals.csv",
          meal_id: [meal1.id, meal2.id]))
      end

      context "as a regular user" do
        let(:actor) { create(:user) }

        it "omits the cost columns" do
          csv = exporter.to_csv
          expect(csv).not_to match(/Ingredient Cost/)
          expect(csv).not_to match(/Reimbursee/)
          expect(csv).not_to match(/Price: Adult/)
          expect(csv).to match(/Diners: Adult/)
        end
      end
    end
  end
end

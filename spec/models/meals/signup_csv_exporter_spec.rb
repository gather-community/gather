# frozen_string_literal: true

require "rails_helper"

describe Meals::SignupCsvExporter do
  let(:community) { Defaults.community }
  let(:actor) { create(:meals_coordinator) }
  let(:policy) { Meals::SignupPolicy.new(actor, Meals::Signup.new(meal: Meals::Meal.new)) }
  let(:scope) do
    Meals::Signup.joins(:meal).joins(household: :community)
      .order("meals.served_at", "communities.abbrv", "households.name")
  end
  let(:exporter) { described_class.new(scope, policy: policy, community: community) }

  describe "to_csv" do
    context "with no signups" do
      it "returns valid csv" do
        # Full headers are tested below.
        expect(exporter.to_csv).to match(/\AMeal ID,/)
      end
    end

    context "with signups" do
      let!(:other_community) { create(:community, name: "Bravo", abbrv: "BV") }
      let!(:calendar) { create(:calendar, name: "Dining Room", meal_hostable: true) }
      let!(:formula) do
        create(:meal_formula, name: "Standard",
          parts_attrs: [{type: "Adult", share: "100%"}, {type: "Teen", share: "75%"}])
      end

      # Active in the community but not part of the formula, so its column should be blank.
      let!(:unused_type) { create(:meal_type, name: "Senior", category: "Meat") }

      let!(:meal) do
        create(:meal, :with_menu, formula: formula, calendars: [calendar], community: community,
          communities: [community, other_community], served_at: "2018-11-05 18:00",
          title: "Tacos")
      end

      # Deliberately created out of household-name order to ensure the sort is respected.
      let!(:households) do
        [create(:household, name: "Smith"), create(:household, name: "Li")]
      end

      before do
        Timecop.freeze("2018-11-01 12:00") do
          create(:meal_signup, meal: meal, household: households[0], diner_counts: [2, 1])
          create(:meal_signup, meal: meal, household: households[1], diner_counts: [1, 0],
            takeout: true, comments: "No onions, please")
        end
      end

      it "returns valid csv" do
        expect(exporter.to_csv).to eq(prepare_fixture("meals/signups.csv",
          meal_id: [meal.id],
          household_id: [households[1].id, households[0].id],
          community_id: [community.id]))
      end
    end
  end
end

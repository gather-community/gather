# frozen_string_literal: true

require "rails_helper"

describe Meals::PortionCountBuilder do
  subject(:html) { described_class.new(meal.reload).portion_counts }

  context "with no categores" do
    let(:formula) do
      create(:meal_formula, meal_calc_type: "share",
                            parts_attrs: [{share: "100%", portion: 1}, {share: "75%", portion: 0.5}])
    end
    let(:meal) { create(:meal, formula: formula) }
    let!(:signups) do
      [
        create(:meal_signup, meal: meal, diner_counts: [2, 3]),
        create(:meal_signup, meal: meal, diner_counts: [0, 1])
      ]
    end

    it {
      is_expected.to match("This meal has <strong>6 diners</strong> and will require approximately <strong>4</strong> portions.")
    }
  end

  context "with categores" do
    let(:formula) do
      create(:meal_formula, meal_calc_type: "share",
                            parts_attrs: [{share: "100%", category: "Meat", portion: 1},
                                          {share: "75%", category: "Meat", portion: 0.5},
                                          {share: "100%", category: "Veg", portion: 1}])
    end
    let(:meal) { create(:meal, formula: formula) }
    let!(:signups) do
      [
        create(:meal_signup, meal: meal, diner_counts: [2, 3, 1]),
        create(:meal_signup, meal: meal, diner_counts: [0, 3, 1])
      ]
    end

    it do
      is_expected.to match("This meal has <strong>10 diners</strong> and will require approximately: <strong>5 Meat</strong> portions, " \
                           "<strong>2 Veg</strong> portions.")
    end
  end

  context "with mix of categores and no categories" do
    let(:formula) do
      create(:meal_formula, meal_calc_type: "share",
                            parts_attrs: [{share: "100%", category: "Meat", portion: 1},
                                          {share: "75%", portion: 0.5},
                                          {share: "100%", category: "Veg", portion: 1}])
    end
    let(:meal) { create(:meal, formula: formula) }
    let!(:signups) do
      [
        create(:meal_signup, meal: meal, diner_counts: [2, 3, 1]),
        create(:meal_signup, meal: meal, diner_counts: [0, 3, 1])
      ]
    end

    it do
      is_expected.to match("This meal has <strong>10 diners</strong> and will require approximately: <strong>2 Meat</strong> portions, " \
                           "<strong>2 Veg</strong> portions, <strong>3 other</strong> portions.")
    end
  end
end

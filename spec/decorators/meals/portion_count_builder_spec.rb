# frozen_string_literal: true

require "rails_helper"

describe Meals::PortionCountBuilder do
  subject(:html) { described_class.new(meal.reload).portion_counts }

  context "with no categores" do
    let(:formula) do
      create(:meal_formula, meal_calc_type: "share", part_shares: [["100%", nil, 1], ["75%", nil, 0.5]])
    end
    let(:meal) { create(:meal, formula: formula) }
    let!(:signups) do
      [
        create(:meal_signup, meal: meal, diner_counts: [2, 3]),
        create(:meal_signup, meal: meal, diner_counts: [0, 1])
      ]
    end

    it { is_expected.to match("This meal will require approximately <strong>4</strong> portions.") }
  end
end

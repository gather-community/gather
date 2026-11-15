# frozen_string_literal: true

require "rails_helper"
require "fileutils"

describe Utils::Generators::MealGenerator do
  let(:community) { create(:community) }
  let!(:kitchen) { create(:calendar, name: "Kitchen") }
  let!(:dining_room) { create(:calendar, name: "Dining Room") }
  let!(:users) { create_list(:user, 5) }
  let(:generator) do
    described_class.new(community: community, statement_gen: double(generate_samples: nil),
      calendar_map: {116 => kitchen, 21 => dining_room})
  end

  it "should run cleanly" do
    generator.generate_seed_data
    generator.generate_samples

    # Don't create extra roles or formulas
    expect(Meals::Formula.all.map(&:name)).to contain_exactly("Default Formula")
    expect(Meals::Role.all.map(&:title)).to contain_exactly("Head Cook", "Assistant Cook", "Cleaner")
    expect(Meals::Meal.all.flat_map(&:calendars).uniq).to contain_exactly(kitchen, dining_room)

    # Menus come from sample_data.yml. The last row in meals.yml is used first.
    salmon = Meals::Meal.find_by!(title: "Salmon en Papillote")
    expect(salmon.entrees).to eq("Salmon baked in parchment, seasoned with onion and herbs")
    expect(salmon.allergens).to be_empty
    expect(salmon.no_allergens).to be(true)
    expect(Meals::Meal.find_by!(title: "Soup Bar!").allergens).to eq(["Dairy"])
  end
end

# frozen_string_literal: true

require "rails_helper"
require "fileutils"

describe Utils::Generators::MealGenerator do
  let(:community) { create(:community) }
  let!(:kitchen) { create(:calendar, name: "Kitchen") }
  let!(:dining_room) { create(:calendar, name: "Dining Room") }
  let!(:users) { create_list(:user, 5) }
  let(:generator) { described_class.new(community: community, statement_gen: double(generate_samples: nil)) }

  it "should run cleanly" do
    generator.generate_formula_and_roles
    generator.generate_samples

    # Don't create extra roles or formulas
    expect(Meals::Formula.all.map(&:name)).to contain_exactly("Default Formula")
    expect(Meals::Role.all.map(&:title)).to contain_exactly("Head Cook", "Assistant Cook", "Cleaner")
  end
end

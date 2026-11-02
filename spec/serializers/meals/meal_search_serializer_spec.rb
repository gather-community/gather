# frozen_string_literal: true

require "rails_helper"

describe Meals::MealSearchSerializer do
  let(:community) { Defaults.community }
  let(:meal) { create(:meal, community: community) }

  subject(:data) { described_class.new(meal).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: meal.id,
      kind: "meal",
      community_id: community.id
    )
    expect(data).to have_key(:title)
    expect(data).to have_key(:served_at)
  end
end

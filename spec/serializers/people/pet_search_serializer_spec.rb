# frozen_string_literal: true

require "rails_helper"

describe People::PetSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community) }
  let(:pet) { create(:pet, household: household, name: "Whiskers", species: "cat") }

  subject(:data) { described_class.new(pet).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: pet.id,
      kind: "pet",
      community_id: community.id,
      household_id: household.id,
      name: "Whiskers",
      species: "cat"
    )
  end
end

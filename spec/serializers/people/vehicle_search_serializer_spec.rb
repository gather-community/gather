# frozen_string_literal: true

require "rails_helper"

describe People::VehicleSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community) }
  let(:vehicle) { create(:vehicle, household: household, make: "Toyota", model: "Prius", plate: "XYZ1234") }

  subject(:data) { described_class.new(vehicle).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: vehicle.id,
      kind: "vehicle",
      community_id: community.id,
      household_id: household.id,
      make: "Toyota",
      model: "Prius",
      plate: "XYZ1234"
    )
  end
end

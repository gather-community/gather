# frozen_string_literal: true

require "rails_helper"

describe HouseholdSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community, name: "Smith House") }

  subject(:data) { described_class.new(household).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: household.id,
      kind: "household",
      community_id: community.id,
      name: "Smith House"
    )
  end
end

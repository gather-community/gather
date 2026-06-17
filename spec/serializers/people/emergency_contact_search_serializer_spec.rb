# frozen_string_literal: true

require "rails_helper"

describe People::EmergencyContactSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community) }
  let(:contact) do
    create(:emergency_contact, household: household, name: "Bob Jones", relationship: "sibling")
  end

  subject(:data) { described_class.new(contact).as_json }

  it "includes required fields" do
    expect(data).to include(
      id: contact.id,
      kind: "emergency_contact",
      community_id: community.id,
      household_id: household.id,
      name: "Bob Jones",
      relationship: "sibling"
    )
  end
end

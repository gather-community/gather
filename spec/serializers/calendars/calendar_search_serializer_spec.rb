# frozen_string_literal: true

require "rails_helper"

describe Calendars::CalendarSearchSerializer do
  let(:community) { Defaults.community }
  let(:calendar) { create(:calendar, community: community, name: "Community Events") }

  subject(:data) { described_class.new(calendar).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: calendar.id,
      kind: "calendar",
      community_id: community.id,
      name: "Community Events"
    )
    expect(data).to have_key(:guidelines)
  end
end

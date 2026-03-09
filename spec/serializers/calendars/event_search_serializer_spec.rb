# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventSearchSerializer do
  let(:community) { Defaults.community }
  let(:calendar) { create(:calendar, community: community) }
  let(:event) { create(:event, calendar: calendar, name: "Annual Meeting", note: "All welcome.") }

  subject(:data) { described_class.new(event).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: event.id,
      kind: "event",
      community_id: community.id,
      calendar_id: calendar.id,
      name: "Annual Meeting",
      note: "All welcome."
    )
  end
end

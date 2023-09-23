# frozen_string_literal: true

require "rails_helper"

describe Calendars::System::JoinDatesCalendar do
  include_context "system calendars"

  let(:actor) { create(:user) }
  let(:calendar) { create(:join_dates_calendar) }
  let!(:user1) do
    create(:user, first_name: "Jo", last_name: "Fiz", joined_on: "Jan 28 2013")
  end
  let(:full_range) { Date.new(2021, 1, 1)..Date.new(2021, 12, 31) }

  around do |example|
    Timecop.freeze("2021-09-26 9:00") do
      example.run
    end
  end

  it "returns correct event attribs" do
    attribs = [{
      name: "➕ Jo Fiz (8)",
      starts_at: Time.zone.parse("2021-01-28 00:00"),
      ends_at: Time.zone.parse("2021-01-28 23:59:59"),
      all_day: true,
      creator_temp_id: nil,
      note: nil,
      linkable: user1,
      uid: "join_dates_#{user1.id}"
    }]
    events = calendar.events_between(full_range, actor: actor)
    expect_events(events, *attribs)
  end
end

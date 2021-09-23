# frozen_string_literal: true

require "rails_helper"

describe "events exports" do
  include_context "calendar exports"

  let(:time) { Time.zone.parse("2019-08-29 13:00") }
  let(:user2) { create(:user) }
  let(:calendar1) { create(:calendar, name: "Fun Room") }
  let(:calendar2) { create(:calendar, name: "Sad Room") }
  let!(:event1) do
    create(:event, starts_at: time + 1.hour, ends_at: time + 90.minutes,
                   calendar: calendar1, creator: user, name: "Games")
  end
  let!(:event2) do
    create(:event, calendar: calendar1, starts_at: time + 2.hours, ends_at: time + 3.hours,
                   name: "Dance", creator: user2)
  end
  # Identical times, creator, and name; should be combined
  let!(:event3) do
    create(:event, calendar: calendar2, starts_at: time + 2.hours, ends_at: time + 3.hours,
                   name: "Dance", creator: user2)
  end
  let!(:event4) do
    create(:event, calendar: calendar2, all_day: true, starts_at: time.tomorrow, ends_at: time + 2.days,
                   name: "Funday", creator: user2)
  end
  let!(:other_cmty_event) do
    create(:event, name: "Nope", calendar: create(:calendar, community: communityB))
  end

  around do |example|
    Timecop.freeze(time) { example.run }
  end

  context "your events" do
    subject(:ical_data) { Calendars::Exports::YourEventsExport.new(user: user).generate }

    it do
      expect_calendar_name("Your Events")
      expect_events(
        summary: "Games (#{user.name})",
        location: "Fun Room",
        description: %r{http://.+/calendars/events/},
        "DTSTART;TZID=Etc/UTC" => (time + 1.hour).to_s(:no_sep),
        "DTEND;TZID=Etc/UTC" => (time + 90.minutes).to_s(:no_sep)
      )
      expect(ical_data).not_to match("Dance")
    end
  end

  shared_examples_for "community events" do
    it do
      # rubocop:disable Style/BracesAroundHashParameters
      expect_calendar_name("#{user.community.name} Events")
      expect_events({
        summary: "Games (#{event1.creator.name})",
        location: "Fun Room"
      }, {
        summary: "Dance (#{event2.creator.name})",
        location: [calendar1, calendar2].sort_by(&:id).map(&:name).join(" + ")
      }, {
        summary: "Funday (#{event4.creator.name})",
        location: "Sad Room",
        "DTSTART;VALUE=DATE" => "20190830",
        "DTEND;VALUE=DATE" => "20190831"
      })
      # rubocop:enable Style/BracesAroundHashParameters
    end
  end

  context "community events (personalized)" do
    subject(:ical_data) { Calendars::Exports::CommunityEventsExport.new(user: user).generate }
    it_behaves_like "community events"
  end

  context "community events (not personalized)" do
    subject(:ical_data) { Calendars::Exports::CommunityEventsExport.new(community: community).generate }
    it_behaves_like "community events"
  end
end

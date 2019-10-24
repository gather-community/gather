# frozen_string_literal: true

require "rails_helper"

describe "reservations exports" do
  include_context "calendar exports"

  let(:time) { Time.zone.parse("2019-08-29 13:00") }
  let(:user2) { create(:user) }
  let(:resource1) { create(:resource, name: "Fun Room") }
  let(:resource2) { create(:resource, name: "Sad Room") }
  let!(:reservation1) do
    create(:reservation, starts_at: time + 1.hour, ends_at: time + 90.minutes,
                         resource: resource1, reserver: user, name: "Games")
  end
  let!(:reservation2) do
    create(:reservation, resource: resource1, starts_at: time + 2.hours, reserver: user2,
                         ends_at: time + 3.hours, name: "Dance")
  end
  # Identical times, reserver, and name
  let!(:reservation3) do
    create(:reservation, resource: resource2, starts_at: time + 2.hours, reserver: user2,
                         ends_at: time + 3.hours, name: "Dance")
  end
  let!(:other_cmty_reservation) do
    create(:reservation, name: "Nope", resource: create(:resource, community: communityB))
  end

  around do |example|
    Timecop.freeze(time) { example.run }
  end

  context "your reservations" do
    subject(:ical_data) { Calendars::Exports::YourReservationsExport.new(user: user).generate }

    it do
      expect_calendar_name("Your Reservations")
      expect_events(
        summary: "Games (#{user.name})",
        location: "Fun Room",
        description: %r{http://.+/reservations/},
        "DTSTART;TZID=Etc/UTC" => (time + 1.hour).to_s(:iso8601_no_sep),
        "DTEND;TZID=Etc/UTC" => (time + 90.minutes).to_s(:iso8601_no_sep)
      )
      expect(ical_data).not_to match("Dance")
    end
  end

  shared_examples_for "community reservations" do
    it do
      expect_calendar_name("#{user.community.name} Reservations")
      expect_events({
        summary: "Games (#{reservation1.reserver.name})",
        location: "Fun Room"
      }, {
        summary: "Dance (#{reservation2.reserver.name})",
        location: [resource1, resource2].sort_by(&:id).map(&:name).join(" + ")
      })
    end
  end

  context "community reservations (personalized)" do
    subject(:ical_data) { Calendars::Exports::CommunityReservationsExport.new(user: user).generate }
    it_behaves_like "community reservations"
  end

  context "community reservations (not personalized)" do
    subject(:ical_data) { Calendars::Exports::CommunityReservationsExport.new(community: community).generate }
    it_behaves_like "community reservations"
  end
end

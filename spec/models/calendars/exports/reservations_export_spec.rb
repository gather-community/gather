# frozen_string_literal: true

require "rails_helper"

describe "reservations exports" do
  include_context "calendar exports"

  let(:resource) { create(:resource, name: "Fun Room") }
  let(:reservation1_time) { Time.current + 1.hour }
  let!(:reservation1) do
    create(:reservation, starts_at: reservation1_time, ends_at: reservation1_time + 90.minutes,
                         resource: resource, reserver: user, name: "Games")
  end
  let!(:reservation2) { create(:reservation, starts_at: Time.current + 2.hours, name: "Dance") }
  let!(:other_cmty_reservation) do
    create(:reservation, name: "Nope", resource: create(:resource, community: communityB))
  end

  context "your reservations" do
    subject(:ical_data) { Calendars::Exports::YourReservationsExport.new(user: user).generate }

    it do
      expect_calendar_name("Your Reservations")
      expect_events(
        summary: "Games (#{user.name})",
        location: "Fun Room",
        description: %r{http://.+/reservations/},
        "DTSTART;TZID=Etc/UTC" => I18n.l(reservation1_time, format: :iso),
        "DTEND;TZID=Etc/UTC" => I18n.l(reservation1_time + 90.minutes, format: :iso)
      )
      expect(ical_data).not_to match("Dance")
    end
  end

  shared_examples_for "community reservations" do
    it do
      expect_calendar_name("#{user.community.name} Reservations")
      expect_events({
        summary: "Games (#{reservation1.reserver.name})"
      }, {
        summary: "Dance (#{reservation2.reserver.name})"
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

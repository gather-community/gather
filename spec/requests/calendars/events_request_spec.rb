# frozen_string_literal: true

require "rails_helper"

describe "calendar events JSON endpoint" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community) }
  let(:range_start) { "2026-06-15T00:00:00" }
  let(:range_end) { "2026-06-22T00:00:00" }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  def fetch_events
    get("/calendars/events", params: {
      start: range_start,
      end: range_end,
      calendar_ids: calendar.id.to_s
    }, xhr: true)
    JSON.parse(response.body)
  end

  context "with a regular non-recurring event in range" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-18 10:00", ends_at: "2026-06-18 11:00")
    end

    it "returns correctly shaped JSON" do
      data = fetch_events
      expect(data.size).to eq(1)
      entry = data.first
      expect(entry["title"]).to eq(event.name)
      expect(entry["start"]).to eq("2026-06-18T10:00:00")
      expect(entry["end"]).to eq("2026-06-18T11:00:00")
      expect(entry["calendarId"]).to eq(calendar.id)
      expect(entry["url"]).to include("/calendars/eventlets/#{event.eventlets.first.id}")
      expect(entry).to have_key("editable")
      expect(entry).to have_key("backgroundColor")
    end
  end

  context "with a recurring event whose occurrence falls in range" do
    # Anchor is one week before range start; daily recurrence puts an occurrence on Jun 15.
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-08 14:00", ends_at: "2026-06-08 15:00",
        recurrence_rule: IceCube::Rule.weekly.to_hash)
    end

    it "returns one entry per occurrence with correctly shaped JSON" do
      data = fetch_events
      expect(data.size).to eq(1)
      entry = data.first
      expect(entry["title"]).to eq(event.name)
      expect(entry["start"]).to eq("2026-06-15T14:00:00")
      expect(entry["end"]).to eq("2026-06-15T15:00:00")
      expect(entry["calendarId"]).to eq(calendar.id)
      expect(entry["url"]).to include("/calendars/eventlets/#{event.eventlets.first.id}?occurrence=")
      expect(entry).to have_key("editable")
      expect(entry).to have_key("backgroundColor")
    end

    it "does not return the underlying eventlet for the recurring event" do
      data = fetch_events
      # All returned entries must use the occurrence start time, not the anchor date.
      data.each do |entry|
        expect(entry["start"]).not_to include("2026-06-08")
      end
    end
  end

  context "with a recurring event whose series ended before the range" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-01 10:00", ends_at: "2026-06-01 11:00",
        recurrence_rule: IceCube::Rule.weekly.until(Date.new(2026, 6, 7)).to_hash)
    end

    it "returns no entries" do
      expect(fetch_events).to be_empty
    end
  end
end

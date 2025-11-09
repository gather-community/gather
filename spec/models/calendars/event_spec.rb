# frozen_string_literal: true

require "rails_helper"

describe Calendars::Event do
  let(:allow_overlap) { false }
  let(:calendar) { create(:calendar, allow_overlap: allow_overlap) }
  let(:calendar2) { create(:calendar) }

  it "has a valid factory" do
    create(:event)
    create(:event, group: create(:group))
  end

  describe "eventlet sync" do
    it "syncs eventlet on create and update" do
      event = create(:event, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")

      expect(event.eventlets.size).to eq(1)

      eventlet = event.eventlets.first
      expect(eventlet.event_id).to eq(event.id)
      expect(eventlet.calendar_id).to eq(event.calendar_id)
      expect(eventlet.cluster_id).to eq(event.cluster_id)
      expect(eventlet.starts_at).to eq("2016-04-07 12:00")
      expect(eventlet.ends_at).to eq("2016-04-07 13:00")

      event.update!(starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 14:00")
      expect(eventlet.starts_at).to eq("2016-04-07 13:00")
      expect(eventlet.ends_at).to eq("2016-04-07 14:00")

      expect(event.eventlets.size).to eq(1)

      # Ensure that references still intact
      eventlet = event.eventlets.first.reload
      expect(eventlet.starts_at).to eq("2016-04-07 13:00")
      expect(eventlet.ends_at).to eq("2016-04-07 14:00")
    end
  end

  describe "meal event handler interactions" do
    let(:meal) { create(:meal, calendars: [create(:calendar)]) }
    let(:event) { meal.events.first }

    before do
      meal.build_events
      meal.save!
    end

    it "should call validate_event and then sync_resourcings" do
      event.starts_at += 1.minute
      expect(meal.event_handler).to receive(:validate_event).with(event)
      expect(meal.event_handler).to receive(:sync_resourcings).with(event)
      event.save!
    end
  end

  describe "location" do
    let(:calendar) { create(:calendar, name: "Fun Room") }
    subject(:location) { event.location }

    context "with persisted event and no explicit location" do
      let(:event) { create(:event, calendar: calendar) }

      it "returns calendar name as location" do
        expect(event.location).to eq("Fun Room")
      end
    end

    context "with persisted event but explicit location" do
      let(:event) { create(:event, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(event.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and explicit location" do
      let(:event) { build(:event, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(event.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and no explicit location" do
      let(:event) { build(:event, calendar: calendar, location: nil) }

      it "returns nil" do
        expect(event.location).to be_nil
      end
    end
  end
end

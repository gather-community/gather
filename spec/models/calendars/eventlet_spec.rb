# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_eventlets
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  event_id     :bigint           not null
#  calendar_id  :bigint           not null
#  start_offset :integer          not null, default: 0
#  end_offset   :integer          not null, default: 0
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require "rails_helper"

describe Calendars::Eventlet do
  let(:allow_overlap) { false }
  let(:calendar) { create(:calendar, allow_overlap: allow_overlap) }

  it "has a valid factory with event and not duplicate eventlets" do
    eventlet = create(:eventlet)
    expect(Calendars::Eventlet.count).to eq(1)
    expect(Calendars::Event.count).to eq(1)
    expect(eventlet.event).not_to be_nil
    expect(eventlet.event.reload).not_to be_nil
  end

  describe "starts_at and ends_at virtual attributes" do
    let(:event) { build(:event, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 14:00") }
    let(:eventlet) { build(:eventlet, event: event, start_offset: 1800, end_offset: -3600) }

    it "computes starts_at from event.starts_at + start_offset" do
      expect(eventlet.starts_at).to eq(event.starts_at + 1800.seconds)
    end

    it "computes ends_at from event.ends_at + end_offset" do
      expect(eventlet.ends_at).to eq(event.ends_at - 3600.seconds)
    end
  end

  describe "offset validation" do
    let(:max) { Calendars::Eventlet::MAX_OFFSET_SECONDS }

    it "accepts offsets within the maximum" do
      eventlet = build(:eventlet, start_offset: max, end_offset: -max)
      eventlet.validate
      expect(eventlet.errors[:start_offset]).to be_empty
      expect(eventlet.errors[:end_offset]).to be_empty
    end

    it "rejects start_offset exceeding the maximum" do
      eventlet = build(:eventlet, start_offset: max + 1)
      eventlet.validate
      expect(eventlet.errors[:start_offset]).not_to be_empty
    end

    it "rejects end_offset exceeding the maximum in magnitude" do
      eventlet = build(:eventlet, end_offset: -(max + 1))
      eventlet.validate
      expect(eventlet.errors[:end_offset]).not_to be_empty
    end
  end

  describe "all_day_permitted" do
    let(:eventlet) { build(:eventlet, all_day: true) }

    before do
      allow(eventlet).to receive(:rule_set).and_return(double(timed_events_only?: timed_only))
    end

    context "with calendar permitting all day events" do
      let(:timed_only) { false }

      it "is valid" do
        eventlet.validate
        expect(eventlet.errors[:base]).to be_empty
      end
    end

    context "with calendar not permitting all day events" do
      let(:timed_only) { true }

      it "adds an error" do
        eventlet.validate
        expect(eventlet.errors[:base]).to include("All-day events are not allowed for this calendar")
      end
    end
  end

  describe "location" do
    let(:calendar) { create(:calendar, name: "Fun Room") }
    subject(:location) { eventlet.location }

    context "with persisted event and no explicit location" do
      let(:eventlet) { create(:eventlet, calendar: calendar) }

      it "returns calendar name as location" do
        expect(eventlet.location).to eq("Fun Room")
      end
    end

    context "with persisted event but explicit location" do
      let(:eventlet) { create(:eventlet, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(eventlet.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and explicit location" do
      let(:eventlet) { build(:eventlet, calendar: calendar, location: "Martian surface") }

      it "returns explicit location" do
        expect(eventlet.location).to eq("Martian surface")
      end
    end

    context "with unpersisted event and no explicit location" do
      let(:eventlet) { build(:eventlet, calendar: calendar, location: nil) }

      it "returns nil" do
        expect(eventlet.location).to be_nil
      end
    end
  end
end

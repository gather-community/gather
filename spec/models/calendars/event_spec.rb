# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_events
#
#  id          :integer          not null, primary key
#  all_day     :boolean          default(FALSE), not null
#  calendar_id :integer          not null
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  creator_id  :integer
#  ends_at     :datetime         not null
#  group_id    :bigint
#  kind        :string
#  meal_id     :integer
#  name        :string(24)       not null
#  note        :text
#  sponsor_id  :integer
#  starts_at   :datetime         not null
#  updated_at  :datetime         not null
#
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
      expect(eventlet.start_offset).to eq(0)
      expect(eventlet.end_offset).to eq(0)

      event.update!(starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 14:00")
      expect(event.eventlets.size).to eq(1)

      # Times are computed from the event; reload both to confirm DB state.
      eventlet = event.eventlets.first.reload
      expect(eventlet.starts_at).to eq("2016-04-07 13:00")
      expect(eventlet.ends_at).to eq("2016-04-07 14:00")
    end
  end

  describe "normalization" do
    describe "all_day events" do
      context "with all_day false" do
        let(:event) do
          build(:event, all_day: false, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")
        end

        it "does not alter times" do
          event.validate
          expect(event.starts_at.to_fs(:default)).to eq("2016-04-07T12:00:00")
          expect(event.ends_at.to_fs(:default)).to eq("2016-04-07T13:00:00")
        end
      end

      context "with all_day true" do
        let(:event) do
          build(:event, all_day: true, starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")
        end

        it "normalizes to midnight boundaries" do
          event.validate
          expect(event.starts_at.to_fs(:default)).to eq("2016-04-07T00:00:00")
          expect(event.ends_at.to_fs(:default)).to eq("2016-04-07T23:59:59")
        end
      end
    end
  end

  describe "meal event handler interactions" do
    let(:meal) { create(:meal, calendars: [create(:calendar)]) }
    let(:event) { meal.events.first }

    before do
      meal.build_events
    end

    it "should call validate_event and then sync_resourcings" do
      event.starts_at += 1.minute
      expect(meal.event_handler).to receive(:validate_event).with(event)
      expect(meal.event_handler).to receive(:sync_resourcings).with(event)
      meal.save!
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

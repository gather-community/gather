# frozen_string_literal: true

require "rails_helper"

describe Calendars::MultiEventForm do
  let(:current_user) { create(:user) }
  let(:calendar1) { create(:calendar, allow_overlap: false) }
  let(:calendar2) { create(:calendar, allow_overlap: false) }

  def build_form(action: :create, id: nil, calendar_ids: [calendar1.id],
    starts_at: "2026-04-10 12:00", ends_at: "2026-04-10 13:00",
    guidelines_ok: "1", all_day: "0", extra_params: {})
    slot_attrs = calendar_ids.each_with_index.to_h do |cid, i|
      [i.to_s, {"calendar_id" => cid.to_s, "customize_times" => "0"}]
    end
    Calendars::MultiEventForm.new(
      action: action,
      current_user: current_user,
      id: id,
      params: {
        name: "Test Event",
        starts_at: starts_at,
        ends_at: ends_at,
        all_day: all_day,
        guidelines_ok: guidelines_ok,
        calendar_slots_attributes: slot_attrs
      }.merge(extra_params)
    )
  end

  def build_form_with_override(calendar_ids: [calendar1.id, calendar2.id],
    override_calendar_index: 1,
    override_starts_at: "2026-04-10 14:00",
    override_ends_at: "2026-04-10 15:00")
    slot_attrs = calendar_ids.each_with_index.to_h do |cid, i|
      attrs = {"calendar_id" => cid.to_s, "customize_times" => "0"}
      if i == override_calendar_index
        attrs["customize_times"] = "1"
        attrs["starts_at"] = override_starts_at
        attrs["ends_at"] = override_ends_at
      end
      [i.to_s, attrs]
    end
    Calendars::MultiEventForm.new(
      action: :create,
      current_user: current_user,
      params: {
        name: "Override Event",
        starts_at: "2026-04-10 12:00",
        ends_at: "2026-04-10 13:00",
        guidelines_ok: "1",
        calendar_slots_attributes: slot_attrs
      }
    )
  end

  describe "#initialize from params" do
    subject(:form) { build_form(calendar_ids: [calendar1.id, calendar2.id]) }

    it "builds one CalendarSlot per entry" do
      expect(form.calendar_slots.size).to eq(2)
    end

    it "parses starts_at" do
      expect(form.starts_at.to_fs(:default)).to eq("2026-04-10T12:00:00")
    end

    it "parses ends_at" do
      expect(form.ends_at.to_fs(:default)).to eq("2026-04-10T13:00:00")
    end

    it "assigns calendar_id on slots" do
      expect(form.calendar_slots.map { |s|
        s.calendar_id.to_i
      }).to contain_exactly(calendar1.id, calendar2.id)
    end
  end

  describe "#initialize from existing event (edit)" do
    let!(:event) do
      ev = create(:event, calendar: calendar1, starts_at: "2026-04-10 12:00", ends_at: "2026-04-10 13:00",
        dont_sync_eventlet: true)
      create(:eventlet, event: ev, calendar: calendar1, starts_at: "2026-04-10 12:00",
        ends_at: "2026-04-10 13:00")
      create(:eventlet, event: ev, calendar: calendar2, starts_at: "2026-04-10 14:00",
        ends_at: "2026-04-10 15:00")
      ev
    end

    subject(:form) do
      Calendars::MultiEventForm.new(action: :edit, current_user: current_user, id: event.id,
        params: {guidelines_ok: "1"})
    end

    it "loads eventlets as calendar slots" do
      expect(form.calendar_slots.size).to eq(2)
    end

    it "detects a slot with matching times as not customized" do
      slot = form.calendar_slots.find { |s| s.calendar_id == calendar1.id }
      expect(slot.customize_times?).to be(false)
    end

    it "detects a slot with different times as customized" do
      slot = form.calendar_slots.find { |s| s.calendar_id == calendar2.id }
      expect(slot.customize_times?).to be(true)
    end

    it "copies event fields" do
      expect(form.name).to eq(event.name)
      expect(form.starts_at).to eq(event.starts_at)
    end
  end

  describe "#save" do
    context "with two calendars" do
      subject(:form) { build_form(calendar_ids: [calendar1.id, calendar2.id]) }

      it "creates one event" do
        expect { form.save }.to change(Calendars::Event, :count).by(1)
      end

      it "creates two eventlets" do
        expect { form.save }.to change(Calendars::Eventlet, :count).by(2)
      end

      it "sets the event calendar to the first slot's calendar" do
        form.save
        expect(form.event.reload.calendar).to eq(calendar1)
      end

      it "eventlets reference the correct calendars" do
        form.save
        eventlet_calendar_ids = form.event.reload.eventlets.map(&:calendar_id)
        expect(eventlet_calendar_ids).to contain_exactly(calendar1.id, calendar2.id)
      end

      it "does not duplicate eventlets via sync_eventlet" do
        form.save
        expect(form.event.reload.eventlets.count).to eq(2)
      end
    end

    context "with time overrides on the second calendar" do
      subject(:form) { build_form_with_override }

      it "uses main times for the non-overriding slot" do
        form.save
        eventlet = form.event.reload.eventlets.find_by(calendar_id: calendar1.id)
        expect(eventlet.starts_at.strftime("%H:%M")).to eq("12:00")
        expect(eventlet.ends_at.strftime("%H:%M")).to eq("13:00")
      end

      it "uses override times for the customized slot" do
        form.save
        eventlet = form.event.reload.eventlets.find_by(calendar_id: calendar2.id)
        expect(eventlet.starts_at.strftime("%H:%M")).to eq("14:00")
        expect(eventlet.ends_at.strftime("%H:%M")).to eq("15:00")
      end
    end

    context "updating an existing event" do
      let!(:event) do
        ev = create(:event, calendar: calendar1, name: "Old Name",
          starts_at: "2026-04-10 12:00", ends_at: "2026-04-10 13:00",
          dont_sync_eventlet: true)
        create(:eventlet, event: ev, calendar: calendar1, starts_at: ev.starts_at, ends_at: ev.ends_at)
        ev
      end

      subject(:form) do
        Calendars::MultiEventForm.new(
          action: :update,
          current_user: current_user,
          id: event.id,
          params: {
            name: "New Name",
            starts_at: "2026-04-10 12:00",
            ends_at: "2026-04-10 14:00",
            guidelines_ok: "1",
            calendar_slots_attributes: {
              "0" => {"id" => event.eventlets.first.id.to_s,
                      "calendar_id" => calendar1.id.to_s,
                      "customize_times" => "0"}
            }
          }
        )
      end

      it "updates the event name" do
        form.save
        expect(event.reload.name).to eq("New Name")
      end

      it "does not create extra eventlets" do
        expect { form.save }.not_to change(Calendars::Eventlet, :count)
      end
    end
  end

  describe "#all_guidelines" do
    let(:cal_with_guidelines) { create(:calendar, guidelines: "Follow the rules") }

    context "when one calendar has guidelines" do
      subject(:form) { build_form(calendar_ids: [cal_with_guidelines.id]) }

      it "returns that calendar's guidelines" do
        expect(form.all_guidelines).to include("Follow the rules")
      end
    end

    context "when multiple calendars share the same guidelines text" do
      let(:cal2_same) { create(:calendar, guidelines: "Follow the rules") }
      subject(:form) { build_form(calendar_ids: [cal_with_guidelines.id, cal2_same.id]) }

      it "deduplicates guidelines" do
        expect(form.all_guidelines).to eq("Follow the rules")
      end
    end

    context "when no calendar has guidelines" do
      subject(:form) { build_form(calendar_ids: [calendar1.id]) }

      it "returns empty string" do
        expect(form.all_guidelines).to be_blank
      end
    end
  end

  describe "validation" do
    describe "calendar_slots_present" do
      subject(:form) do
        Calendars::MultiEventForm.new(
          action: :create,
          current_user: current_user,
          params: {name: "Test", starts_at: "2026-04-10 12:00", ends_at: "2026-04-10 13:00", guidelines_ok: "1",
                   calendar_slots_attributes: {}}
        )
      end

      it { is_expected.to have_errors(base: "At least one calendar must be selected") }
    end

    describe "start_before_end" do
      it "is invalid when starts_at >= ends_at" do
        form = build_form(starts_at: "2026-04-10 14:00", ends_at: "2026-04-10 12:00")
        expect(form).to have_errors(ends_at: "must be after start time")
      end

      it "is valid when starts_at < ends_at" do
        form = build_form(starts_at: "2026-04-10 12:00", ends_at: "2026-04-10 13:00")
        expect(form).to be_valid
      end
    end

    describe "guidelines_accepted" do
      let(:cal_with_guidelines) { create(:calendar, guidelines: "Please be kind") }

      it "is invalid when guidelines not accepted" do
        form = build_form(calendar_ids: [cal_with_guidelines.id], guidelines_ok: "0")
        expect(form).to have_errors(guidelines: "You must agree to the guidelines")
      end

      it "is valid when guidelines accepted" do
        form = build_form(calendar_ids: [cal_with_guidelines.id], guidelines_ok: "1")
        expect(form).to be_valid
      end

      it "is valid when no calendar has guidelines" do
        form = build_form(calendar_ids: [calendar1.id], guidelines_ok: nil)
        expect(form).to be_valid
      end
    end

    describe "per_slot_validations (overlap)" do
      let!(:existing) do
        create(:event, calendar: calendar1, starts_at: "2026-04-10 12:30", ends_at: "2026-04-10 13:30",
          dont_sync_eventlet: true)
      end

      it "flags overlap on the relevant calendar" do
        form = build_form(calendar_ids: [calendar1.id], starts_at: "2026-04-10 12:00",
          ends_at: "2026-04-10 13:00")
        expect(form).to have_errors(base: /overlaps an existing event/)
      end

      it "does not flag overlap on a different calendar" do
        form = build_form(calendar_ids: [calendar2.id], starts_at: "2026-04-10 12:00",
          ends_at: "2026-04-10 13:00")
        expect(form).to be_valid
      end
    end

    describe "name validation" do
      it "is invalid with a blank name" do
        form = build_form(extra_params: {name: ""})
        expect(form).to have_errors(name: /can't be blank/)
      end

      it "is invalid with a name exceeding max length" do
        form = build_form(extra_params: {name: "A" * (Calendars::EventForm::NAME_MAX_LENGTH + 1)})
        expect(form).to have_errors(name: /too long/)
      end
    end
  end

  describe "#event_summaries" do
    subject(:form) { build_form(calendar_ids: [calendar1.id, calendar2.id]) }

    it "returns one summary per active slot" do
      expect(form.event_summaries.size).to eq(2)
    end

    it "includes calendar and times" do
      summary = form.event_summaries.first
      expect(summary[:calendar]).to eq(calendar1)
      expect(summary[:starts_at]).to eq(form.starts_at)
    end

    context "with a customize-times slot" do
      subject(:form) { build_form_with_override }

      it "uses override times for the customized slot's summary" do
        summary = form.event_summaries.find { |s| s[:calendar] == calendar2 }
        expect(summary[:starts_at].strftime("%H:%M")).to eq("14:00")
      end
    end
  end
end

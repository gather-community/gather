# frozen_string_literal: true

require "rails_helper"

describe Calendars::IcalGenerator do
  let(:calendar_name) { "Some Calendar" }
  let(:eventlets) { [] }
  subject(:ical) do
    Timecop.freeze("2021-01-01 12:00") do
      described_class.new(calendar_name: calendar_name, eventlets: eventlets,
        url_options: {host: "foo.com", protocol: "https", port: 443}).generate
    end
  end

  it "includes calendar name line" do
    is_expected.to match(/X-WR-CALNAME:Some Calendar/)
  end

  context "with simple event" do
    let(:eventlets) do
      [create(:eventlet, name: "Some Event",
        starts_at: "2021-01-01 12:00",
        ends_at: "2022-01-01 13:00",
        note: "This is a description",
        location: "A nice place")]
    end

    it "encodes event attributes appropriately" do
      expected = <<-ICAL
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:icalendar-ruby
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        X-WR-CALNAME:Some Calendar
        BEGIN:VTIMEZONE
        TZID:Etc/UTC
        BEGIN:STANDARD
        DTSTART:19700101T000000
        TZOFFSETFROM:+0000
        TZOFFSETTO:+0000
        TZNAME:UTC
        END:STANDARD
        END:VTIMEZONE
        BEGIN:VEVENT
        DTSTAMP:20210101T120000Z
        UID:91a772a5ae4a_#{eventlets[0].id}
        DTSTART;TZID=Etc/UTC:20210101T120000
        DTEND;TZID=Etc/UTC:20220101T130000
        DESCRIPTION:This is a description\\nhttps://foo.com/calendars/events/#{eventlets[0].event_id}
        LOCATION:A nice place
        SUMMARY:Some Event
        END:VEVENT
        END:VCALENDAR
      ICAL
      expect(ical).to match_ical(expected)
    end
  end

  context "with all day event" do
    let(:eventlets) do
      [create(:eventlet, name: "Some Event",
        all_day: true,
        starts_at: "2021-01-02T00:00:00",
        ends_at: "2021-01-02T23:59:59")]
    end

    it "encodes event attributes appropriately" do
      expect(ical).to include_line("DTSTART;VALUE=DATE:20210102")
      expect(ical).to include_line("DTEND;VALUE=DATE:20210103")
    end
  end

  context "with unpersisted event" do
    let(:eventlets) { [build(:eventlet, uid: "stuff_1234", linkable: create(:user))] }

    it "uses uid" do
      expect(ical).to include_line("UID:91a772a5ae4a_stuff_1234")
    end
  end

  context "with unpersisted event with no uid" do
    let(:eventlets) { [build(:eventlet, uid: nil)] }

    it "raises error" do
      expect { ical }.to raise_error(ArgumentError, "all events must specify uid")
    end
  end

  context "with multiline description" do
    let(:description) { ("fishy " * 24) << "\nstuff\nother stuff" }
    let(:eventlets) { [create(:eventlet, note: description)] }

    it "splits line properly" do
      # Per the RFC, the string should actually include the literal string \n for line breaks, which is why
      # we are checking for `\\n`.
      expect(ical).to include_line(
        "DESCRIPTION:fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy fis\r\n" \
        " hy fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy\r\n" \
        "  fishy \\nstuff\\nother stuff\\nhttps://foo.com/calendars/events/#{eventlets[0].event_id}"
      )
    end
  end

  context "with linkable object" do
    let(:user) { create(:user) }
    let(:eventlets) { [create(:eventlet, note: "Stuff", linkable: user)] }

    it "includes an appropriate url" do
      expect(ical).to include_line(
        "DESCRIPTION:Stuff\\nhttps://foo.com/users/#{user.id}"
      )
    end
  end

  context "with persisted event but no linkable object" do
    let(:eventlets) { [create(:eventlet, note: "Stuff")] }

    it "includes an appropriate url" do
      expect(ical).to include_line(
        "DESCRIPTION:Stuff\\nhttps://foo.com/calendars/events/#{eventlets[0].event_id}"
      )
    end
  end

  context "with unpersisted event and no linkable object" do
    let(:eventlets) { [build(:eventlet)] }

    it "includes an appropriate url" do
      expect { ical }.to raise_error(ArgumentError)
    end
  end

  context "with a recurring event" do
    # First occurrence: Monday 2021-01-04. The eventlets represent the second and third Mondays,
    # built the same way EventFinder builds them (non-persisted, linkable = parent event).
    let(:event) do
      create(:event,
        starts_at: Time.zone.parse("2021-01-04 12:00"),
        ends_at: Time.zone.parse("2021-01-04 13:00"),
        recurrence_rule: IceCube::Rule.weekly.to_hash)
    end

    def occurrence_eventlet(occ_starts_at, occ_ends_at)
      transient = Calendars::Event.new(
        name: event.name, kind: event.kind, note: event.note, all_day: event.all_day,
        creator: event.creator, calendar: event.calendar,
        starts_at: occ_starts_at, ends_at: occ_ends_at
      )
      transient.uid = "#{event.id}_#{occ_starts_at.to_i}"
      Calendars::Eventlet.new(event: transient, calendar: event.calendar,
        start_offset: 0, end_offset: 0)
        .tap do |e|
          e.uid = transient.uid
          e.linkable = event
          e.location = event.calendar.name
        end
    end

    let(:second_occ) do
      occurrence_eventlet(Time.zone.parse("2021-01-11 12:00"), Time.zone.parse("2021-01-11 13:00"))
    end
    let(:third_occ) do
      occurrence_eventlet(Time.zone.parse("2021-01-18 12:00"), Time.zone.parse("2021-01-18 13:00"))
    end

    context "with a single occurrence eventlet" do
      let(:eventlets) { [second_occ] }

      it "emits one VEVENT" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(1)
      end

      it "uses the event starts_at (first occurrence) as DTSTART, not the occurrence time" do
        expect(ical).to include_line("DTSTART;TZID=Etc/UTC:20210104T120000")
      end

      it "uses the event ends_at (first occurrence) as DTEND" do
        expect(ical).to include_line("DTEND;TZID=Etc/UTC:20210104T130000")
      end

      it "includes a weekly RRULE" do
        expect(ical).to include_line("RRULE:FREQ=WEEKLY")
      end

      it "uses the event id and calendar id in the UID" do
        expect(ical).to include_line("UID:91a772a5ae4a_#{event.id}_#{event.calendar.id}")
      end

      it "includes the calendar name as location" do
        expect(ical).to include_line("LOCATION:#{event.calendar.name}")
      end

      it "includes the event name as summary" do
        expect(ical).to include_line("SUMMARY:#{event.name}")
      end

      it "includes the event URL in the description" do
        expect(ical).to include("https://foo.com/calendars/events/#{event.id}")
      end

      context "when the event has a note" do
        let(:event) do
          create(:event,
            starts_at: Time.zone.parse("2021-01-04 12:00"),
            ends_at: Time.zone.parse("2021-01-04 13:00"),
            note: "Bring your A-game",
            recurrence_rule: IceCube::Rule.weekly.to_hash)
        end

        it "includes the note before the URL in the description" do
          expect(ical).to include_line(
            "DESCRIPTION:Bring your A-game\\nhttps://foo.com/calendars/events/#{event.id}"
          )
        end
      end
    end

    context "with multiple occurrence eventlets from the same event on the same calendar" do
      let(:eventlets) { [second_occ, third_occ] }

      it "emits only one VEVENT for the series" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(1)
      end
    end

    context "with occurrence eventlets from the same event on different calendars" do
      let(:other_calendar) { create(:calendar) }
      let(:second_occ_other_cal) do
        transient = Calendars::Event.new(
          name: event.name, all_day: event.all_day, creator: event.creator,
          calendar: other_calendar,
          starts_at: Time.zone.parse("2021-01-11 11:45"),
          ends_at: Time.zone.parse("2021-01-11 12:45")
        )
        transient.uid = "#{event.id}_#{Time.zone.parse("2021-01-11 11:45").to_i}"
        Calendars::Eventlet.new(event: transient, calendar: other_calendar,
          start_offset: -900, end_offset: 0)
          .tap do |e|
            e.uid = transient.uid
            e.linkable = event
          end
      end
      let(:eventlets) { [second_occ, second_occ_other_cal] }

      it "emits one VEVENT per calendar" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
      end

      it "uses different UIDs for each calendar's VEVENT" do
        expect(ical).to include_line("UID:91a772a5ae4a_#{event.id}_#{event.calendar.id}")
        expect(ical).to include_line("UID:91a772a5ae4a_#{event.id}_#{other_calendar.id}")
      end

      it "applies the offset to DTSTART for the calendar with an offset" do
        # second_occ has offset 0 → 12:00; second_occ_other_cal has offset -900s → 11:45
        expect(ical).to include_line("DTSTART;TZID=Etc/UTC:20210104T120000")
        expect(ical).to include_line("DTSTART;TZID=Etc/UTC:20210104T114500")
      end
    end

    context "mixed with a regular non-recurring eventlet" do
      let(:plain_eventlet) { create(:eventlet, starts_at: "2021-01-05 10:00", ends_at: "2021-01-05 11:00") }
      let(:eventlets) { [second_occ, plain_eventlet] }

      it "emits separate VEVENTs for recurring and non-recurring events" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
        expect(ical).to include_line("RRULE:FREQ=WEEKLY")
      end
    end

    # Shared helpers for override specs — all reference the second Monday (2021-01-11 12:00).
    let(:occ_time) { Time.zone.parse("2021-01-11 12:00") }
    let(:base_eventlet) { event.eventlets.first }

    def event_override_for(**attrs)
      create(:event_override, event: event, occurrence_start: occ_time, **attrs)
    end

    def eventlet_override_for(event_override, **attrs)
      create(:eventlet_override, event_override: event_override, eventlet: base_eventlet, **attrs)
    end

    # (A) EventOverride deleted — EXDATE only, no replacement VEVENT
    context "(A) EventOverride deleted" do
      let(:eventlets) { [second_occ] }
      before { event_override_for(deleted: true) }

      it "emits one VEVENT (the series)" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(1)
      end

      it "includes an EXDATE for the deleted occurrence" do
        expect(ical).to include_line("EXDATE;TZID=Etc/UTC:20210111T120000")
      end
    end

    # (B) EventOverride moves the occurrence — EXDATE + RECURRENCE-ID VEVENT
    context "(B) EventOverride moves the occurrence" do
      let(:eventlets) { [second_occ] }
      before do
        event_override_for(starts_at: Time.zone.parse("2021-01-12 09:00"),
          ends_at: Time.zone.parse("2021-01-12 10:00"))
      end

      it "emits two VEVENTs: the series and the replacement" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
      end

      it "includes EXDATE for the original time" do
        expect(ical).to include_line("EXDATE;TZID=Etc/UTC:20210111T120000")
      end

      it "includes RECURRENCE-ID pointing to the original time" do
        expect(ical).to include_line("RECURRENCE-ID;TZID=Etc/UTC:20210111T120000")
      end

      it "uses the new times in the replacement VEVENT" do
        expect(ical).to include_line("DTSTART;TZID=Etc/UTC:20210112T090000")
        expect(ical).to include_line("DTEND;TZID=Etc/UTC:20210112T100000")
      end

      it "shares the UID between the series and the replacement VEVENT" do
        expect(ical.scan(/UID:.*/).map(&:strip).uniq.size).to eq(1)
      end
    end

    # (C) EventletOverride deleted (stub EventOverride) — EXDATE for this calendar, no replacement
    context "(C) EventletOverride deleted (calendar-only deletion)" do
      let(:eventlets) { [second_occ] }
      before { eventlet_override_for(event_override_for, deleted: true) }

      it "emits one VEVENT (the series)" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(1)
      end

      it "includes an EXDATE for the deleted occurrence" do
        expect(ical).to include_line("EXDATE;TZID=Etc/UTC:20210111T120000")
      end
    end

    # (D) EventletOverride changes offsets (stub EventOverride) — EXDATE + RECURRENCE-ID with shifted time
    context "(D) EventletOverride shifts the display time" do
      let(:eventlets) { [second_occ] }
      before { eventlet_override_for(event_override_for, start_offset: -3600, end_offset: -3600) }

      it "emits two VEVENTs: the series and the replacement" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
      end

      it "includes EXDATE for the original iCal occurrence time" do
        expect(ical).to include_line("EXDATE;TZID=Etc/UTC:20210111T120000")
      end

      it "includes RECURRENCE-ID at the original time" do
        expect(ical).to include_line("RECURRENCE-ID;TZID=Etc/UTC:20210111T120000")
      end

      it "uses the offset-adjusted time in the replacement VEVENT" do
        # occurrence_start 12:00 + start_offset -3600s = 11:00
        expect(ical).to include_line("DTSTART;TZID=Etc/UTC:20210111T110000")
      end
    end

    # (E) EventOverride moves + EventletOverride shifts — combined times
    context "(E) EventOverride moves and EventletOverride shifts offset" do
      let(:eventlets) { [second_occ] }
      before do
        eo = event_override_for(starts_at: Time.zone.parse("2021-01-12 09:00"),
          ends_at: Time.zone.parse("2021-01-12 10:00"))
        eventlet_override_for(eo, start_offset: -1800, end_offset: -1800)
      end

      it "emits two VEVENTs" do
        expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
      end

      it "uses the combined times: new base + offset" do
        # 09:00 + (-1800s = -30min) = 08:30
        expect(ical).to include_line("DTSTART;TZID=Etc/UTC:20210112T083000")
      end
    end
  end

  context "with groupable eventlets" do
    let(:user) { create(:user) }
    let(:eventlets) do
      [
        create(:eventlet, name: "Some Event",
          creator: user,
          starts_at: "2021-01-01 12:00",
          ends_at: "2022-01-01 13:00",
          note: "This is a description",
          location: "A nice place"),
        create(:eventlet, name: "Some Event",
          creator: user,
          starts_at: "2021-01-01 12:00",
          ends_at: "2022-01-01 13:00",
          note: "Other description",
          location: "Other place"),
        create(:eventlet, name: "Other Event",
          creator: user,
          starts_at: "2021-01-01 12:00",
          ends_at: "2022-01-01 13:00")
      ]
    end

    it "groups first two eventlets" do
      expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
      expect(ical).to include_line("LOCATION:A nice place + Other place")
      expect(ical).to include_line("DESCRIPTION:This is a description\\nOther description\\n" \
        "https://foo.com/calen\r\n dars/events/#{eventlets[0].event_id}")
    end
  end

  def match_ical(expected)
    include(expected.gsub("\n", "\r\n").gsub(/^\s+/m, ""))
  end

  def include_line(line)
    include("\r\n#{line}\r\n")
  end
end

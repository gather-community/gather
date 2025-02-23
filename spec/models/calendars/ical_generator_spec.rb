# frozen_string_literal: true

require "rails_helper"

describe Calendars::IcalGenerator do
  let(:calendar_name) { "Some Calendar" }
  let(:events) { [] }
  subject(:ical) do
    Timecop.freeze("2021-01-01 12:00") do
      described_class.new(calendar_name: calendar_name, events: events,
                          url_options: {host: "foo.com", protocol: "https", port: 443}).generate
    end
  end

  it "includes calendar name line" do
    is_expected.to match(/X-WR-CALNAME:Some Calendar/)
  end

  context "with simple event" do
    let(:events) do
      [create(:event, name: "Some Event",
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
        UID:91a772a5ae4a_#{events[0].id}
        DTSTART;TZID=Etc/UTC:20210101T120000
        DTEND;TZID=Etc/UTC:20220101T130000
        DESCRIPTION:This is a description\\nhttps://foo.com/calendars/events/#{events[0].id}
        LOCATION:A nice place
        SUMMARY:Some Event
        END:VEVENT
        END:VCALENDAR
      ICAL
      expect(ical).to match_ical(expected)
    end
  end

  context "with all day event" do
    let(:events) do
      [create(:event, name: "Some Event",
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
    let(:events) { [build(:event, uid: "stuff_1234", linkable: create(:user))] }

    it "uses uid" do
      expect(ical).to include_line("UID:91a772a5ae4a_stuff_1234")
    end
  end

  context "with unpersisted event with no uid" do
    let(:events) { [build(:event, uid: nil)] }

    it "raises error" do
      expect { ical }.to raise_error(ArgumentError, "all events must specify uid")
    end
  end

  context "with multiline description" do
    let(:description) { ("fishy " * 24) << "\nstuff\nother stuff" }
    let(:events) { [create(:event, note: description)] }

    it "splits line properly" do
      # Per the RFC, the string should actually include the literal string \n for line breaks, which is why
      # we are checking for `\\n`.
      expect(ical).to include_line(
        "DESCRIPTION:fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy fis\r\n " \
        "hy fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy fishy\r\n  " \
        "fishy \\nstuff\\nother stuff\\nhttps://foo.com/calendars/events/#{events[0].id}"
      )
    end
  end

  context "with linkable object" do
    let(:user) { create(:user) }
    let(:events) { [create(:event, note: "Stuff", linkable: user)] }

    it "includes an appropriate url" do
      expect(ical).to include_line(
        "DESCRIPTION:Stuff\\nhttps://foo.com/users/#{user.id}"
      )
    end
  end

  context "with persisted event but no linkable object" do
    let(:events) { [create(:event, note: "Stuff")] }

    it "includes an appropriate url" do
      expect(ical).to include_line(
        "DESCRIPTION:Stuff\\nhttps://foo.com/calendars/events/#{events[0].id}"
      )
    end
  end

  context "with unpersisted event and no linkable object" do
    let(:events) { [build(:event)] }

    it "includes an appropriate url" do
      expect { ical }.to raise_error(ArgumentError)
    end
  end

  context "with groupable events" do
    let(:user) { create(:user) }
    let(:events) do
      [
        create(:event, name: "Some Event",
                       creator: user,
                       starts_at: "2021-01-01 12:00",
                       ends_at: "2022-01-01 13:00",
                       note: "This is a description",
                       location: "A nice place"),
        create(:event, name: "Some Event",
                       creator: user,
                       starts_at: "2021-01-01 12:00",
                       ends_at: "2022-01-01 13:00",
                       note: "Other description",
                       location: "Other place"),
        create(:event, name: "Other Event",
                       creator: user,
                       starts_at: "2021-01-01 12:00",
                       ends_at: "2022-01-01 13:00")
      ]
    end

    it "groups first two events" do
      expect(ical.scan("BEGIN:VEVENT").size).to eq(2)
      expect(ical).to include_line("LOCATION:A nice place + Other place")
      expect(ical).to include_line('DESCRIPTION:This is a description\\nOther description\\n' \
                                   "https://foo.com/calen\r\n dars/events/#{events[0].id}")
    end
  end

  def match_ical(expected)
    include(expected.gsub("\n", "\r\n").gsub(/^\s+/m, ""))
  end

  def include_line(line)
    include("\r\n#{line}\r\n")
  end
end

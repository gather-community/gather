# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::MaxMinutesPerYearRule do
  describe "#check" do
    let(:calendar1) { create(:calendar, name: "Foo Room") }
    let(:calendar2) { create(:calendar, name: "Bar Room") }
    let(:calendar3) { create(:calendar, name: "Baz Room") }
    let(:household) { create(:household) }
    let(:user1) { create(:user, household: household) }
    let(:user2) { create(:user, household: household) }

    # Create 5 hours total events for calendars 1,2,&3 for household.
    let!(:event1) do
      create(:event, creator: user1, calendar: calendar1, kind: "Special",
                     starts_at: "2016-01-01 12:00", ends_at: "2016-01-01 13:00")
    end
    let!(:event2) do
      create(:event, creator: user2, calendar: calendar2, kind: "Personal",
                     starts_at: "2016-01-03 12:00", ends_at: "2016-01-03 13:00")
    end
    let!(:event3) do
      create(:event, creator: user2, calendar: calendar1,
                     starts_at: "2016-01-08 9:00", ends_at: "2016-01-08 10:00")
    end
    let!(:event4) do
      create(:event, creator: user2, calendar: calendar1, kind: "Official",
                     starts_at: "2016-01-11 13:00", ends_at: "2016-01-11 14:00")
    end
    let!(:event5) do
      create(:event, creator: user1, calendar: calendar3,
                     starts_at: "2016-01-11 13:00", ends_at: "2016-01-11 14:00")
    end

    let(:event) { Calendars::Event.new(creator: user1, starts_at: "2016-01-30 6:00pm") }
    let(:rule) do
      described_class.new(value: 180, calendars: [calendar1, calendar2], kinds: %w[Personal Special],
                          community: Defaults.community)
    end

    # Most functionality is in the parent class and covered by max_days_per_year_spec
    # This one covers just the error message formatting and minutes unit.

    it "should work for event 1 hour long" do
      event.ends_at = Time.zone.parse("2016-01-30 7:00pm")
      expect(rule.check(event)).to be(true)
    end

    it "should fail for event 2 hours long" do
      event.ends_at = Time.zone.parse("2016-01-30 8:00pm")
      expect(rule.check(event)).to eq([:base, "You can book at most 3 hours of Personal/Special " \
                                              "Foo Room/Bar Room events per year and you have already booked 2 hours"])
    end

    context "with persisted event" do
      let!(:event) do
        create(:event, creator: user1, starts_at: "2016-01-30 6:00pm", ends_at: "2016-01-30 7:00pm",
                       calendar: calendar1, kind: "Personal")
      end

      it "should ignore the current event on edit" do
        # Assume we are actually shortening this event.
        # It only be a problem if it goes to more than an hour.
        event.ends_at = "2016-01-30 6:50pm"
        expect(rule.check(event)).to be(true)
        event.ends_at = "2016-01-30 7:10pm"
        expect(rule.check(event)).to eq([:base, "You can book at most 3 hours of Personal/Special " \
                                                "Foo Room/Bar Room events per year and you have already booked 2 hours"])
      end
    end
  end
end

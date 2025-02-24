# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::MaxDaysPerYearRule do
  describe "#check" do
    let(:calendar1) { create(:calendar, name: "Foo Room") }
    let(:calendar2) { create(:calendar, name: "Bar Room") }
    let(:calendar3) { create(:calendar, name: "Baz Room") }
    let(:household) { create(:household) }
    let(:user1) { create(:user, household: household) }
    let(:user2) { create(:user, household: household) }

    # Create 110.5 hours total (8 days) events for calendars 1,2,&3 for household.
    let!(:event1) do
      # 8 hours
      create(:event, creator: user1, calendar: calendar1, kind: "Special",
                     starts_at: "2016-01-01 12:00", ends_at: "2016-01-01 20:00")
    end
    let!(:event2) do
      # 26 hours (2 days)
      create(:event, creator: user2, calendar: calendar2, kind: "Personal",
                     starts_at: "2016-01-03 12:00", ends_at: "2016-01-04 14:00")
    end
    let!(:event3) do
      # 3.5 hours
      create(:event, creator: user2, calendar: calendar1,
                     starts_at: "2016-01-08 9:00", ends_at: "2016-01-08 12:30")
    end
    let!(:event4) do
      # 70 hours (3 days)
      create(:event, creator: user2, calendar: calendar1, kind: "Official",
                     starts_at: "2016-01-11 13:00", ends_at: "2016-01-14 11:00")
    end
    let!(:event5) do
      # 3 hours
      create(:event, creator: user1, calendar: calendar3,
                     starts_at: "2016-01-11 13:00", ends_at: "2016-01-11 16:00")
    end

    let(:event) { Calendars::Event.new(creator: user1, starts_at: "2016-01-30 6:00pm") }

    context "rule with kinds and calendars" do
      let(:rule) do
        described_class.new(value: 4, calendars: [calendar1, calendar2], kinds: %w[Personal Special],
                            community: Defaults.community)
      end

      it "should work for event 1 hour long" do
        event.ends_at = Time.zone.parse("2016-01-30 7:00pm")
        expect(rule.check(event)).to be(true)
      end

      it "should fail for event 2 days long" do
        event.ends_at = Time.zone.parse("2016-01-31 9:00pm")
        expect(rule.check(event)).to eq([:base, "You can book at most 4 days of Personal/Special " \
                                                "Foo Room/Bar Room events per year and you have already booked 3 days"])
      end
    end

    context "rule with calendars only" do
      let(:rule) do
        described_class.new(value: max_days, calendars: [calendar1, calendar2], community: Defaults.community)
      end

      context "with max 9 days per year" do
        let(:max_days) { 9 }

        it "should work for event 2 days long" do
          event.ends_at = Time.zone.parse("2016-02-01 12:00pm")
          expect(rule.check(event)).to be(true)
        end

        it "should fail for event 3 days long" do
          event.ends_at = Time.zone.parse("2016-02-01 7:30pm")
          expect(rule.check(event)).to eq([:base, "You can book at most 9 days " \
                                                  "of Foo Room/Bar Room events per year and you have already booked 7 days"])
        end
      end

      context "with max 7 days per year" do
        let(:max_days) { 7 }

        it "should fail for even very short event" do
          event.ends_at = Time.zone.parse("2016-01-30 6:30pm")
          expect(rule.check(event)).to eq([:base, "You can book at most 7 days " \
                                                  "of Foo Room/Bar Room events per year and you have already booked 7 days"])
        end
      end
    end

    context "rule with no calendars or kinds" do
      let(:rule) do
        described_class.new(value: 9, calendars: nil, kinds: nil, community: Defaults.community)
      end

      it "should work for event 1 hour long" do
        event.ends_at = Time.zone.parse("2016-01-30 7:00pm")
        expect(rule.check(event)).to be(true)
      end

      it "should fail for event 2 days long" do
        event.ends_at = Time.zone.parse("2016-01-31 9:00pm")
        expect(rule.check(event)).to eq([:base, "You can book at most 9 days of events " \
                                                "per year and you have already booked 8 days"])
      end
    end

    context "with event with no creator" do
      let(:event) { Calendars::Event.new(creator: nil, starts_at: "2016-01-30 6:00pm") }
      let(:rule) do
        described_class.new(value: 9, calendars: nil, kinds: nil, community: Defaults.community)
      end

      it "should return true" do
        event.ends_at = Time.zone.parse("2016-01-31 9:00pm")
        expect(rule.check(event)).to be(true)
      end
    end
  end
end

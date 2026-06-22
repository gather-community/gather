# frozen_string_literal: true

require "rails_helper"

describe Calendars::EventletDecorator do
  let(:calendar) { create(:calendar) }

  describe "#recurrence_description" do
    context "with a non-recurring eventlet" do
      let(:eventlet) { create(:eventlet, calendar: calendar) }

      it "is nil" do
        expect(eventlet.decorate.recurrence_description).to be_nil
      end
    end

    def description_for(starts_at:, rule:, all_day: false)
      event = create(:event, calendar: calendar, all_day: all_day,
        starts_at: starts_at, ends_at: Time.zone.parse(starts_at) + 1.hour,
        recurrence_rule: rule.to_hash)
      Calendars::OccurrenceResolver.new(event.eventlets.first, nil).resolve.decorate.recurrence_description
    end

    it "describes a daily rule" do
      expect(description_for(starts_at: "2026-06-08 08:00", rule: IceCube::Rule.daily))
        .to eq("Daily at 8:00am")
    end

    it "describes an interval daily rule" do
      expect(description_for(starts_at: "2026-06-08 09:00", rule: IceCube::Rule.daily(3)))
        .to eq("Every 3 days at 9:00am")
    end

    it "infers the month and day for a bare yearly rule" do
      expect(description_for(starts_at: "2026-06-08 16:00", rule: IceCube::Rule.yearly))
        .to eq("Yearly on Jun 08 at 4:00pm")
    end

    it "keeps IceCube's wording for a yearly rule with an explicit month" do
      expect(description_for(starts_at: "2026-06-08 16:00",
        rule: IceCube::Rule.yearly.month_of_year(:june)))
        .to eq("Yearly in June at 4:00pm")
    end

    it "infers the weekday and appends the time for a bare weekly rule" do
      # 2026-06-08 is a Monday.
      expect(description_for(starts_at: "2026-06-08 18:00", rule: IceCube::Rule.weekly))
        .to eq("Weekly on Mondays at 6:00pm")
    end

    it "infers the weekday for an interval weekly rule" do
      # 2026-06-10 is a Wednesday.
      expect(description_for(starts_at: "2026-06-10 11:00", rule: IceCube::Rule.weekly(2)))
        .to eq("Every 2 weeks on Wednesdays at 11:00am")
    end

    it "keeps IceCube's explicit weekdays and appends the time" do
      expect(description_for(starts_at: "2026-06-08 18:00",
        rule: IceCube::Rule.weekly.day(:monday, :thursday)))
        .to eq("Weekly on Mondays and Thursdays at 6:00pm")
    end

    it "describes an nth-weekday monthly rule" do
      expect(description_for(starts_at: "2026-06-03 14:00",
        rule: IceCube::Rule.monthly.day_of_week(wednesday: [1])))
        .to eq("Monthly on the 1st Wednesday at 2:00pm")
    end

    it "shortens an explicit day-of-month rule to match the inferred wording" do
      expect(description_for(starts_at: "2026-06-15 14:00",
        rule: IceCube::Rule.monthly.day_of_month(15)))
        .to eq("Monthly on the 15th at 2:00pm")
    end

    it "shortens a multi-day-of-month rule" do
      expect(description_for(starts_at: "2026-06-15 14:00",
        rule: IceCube::Rule.monthly.day_of_month(15, 20)))
        .to eq("Monthly on the 15th and 20th at 2:00pm")
    end

    it "leaves the 'last day of the month' wording intact" do
      expect(description_for(starts_at: "2026-06-15 14:00",
        rule: IceCube::Rule.monthly.day_of_month(-1)))
        .to eq("Monthly on the last day of the month at 2:00pm")
    end

    it "infers the day-of-month for a bare monthly rule" do
      expect(description_for(starts_at: "2026-06-15 09:00", rule: IceCube::Rule.monthly))
        .to eq("Monthly on the 15th at 9:00am")
    end

    it "formats an until date with Gather's date format" do
      expect(description_for(starts_at: "2026-06-08 18:00",
        rule: IceCube::Rule.weekly.until(Time.zone.parse("2026-08-31"))))
        .to eq("Weekly on Mondays at 6:00pm until Aug 31 2026")
    end

    it "shows the last occurrence date instead of a count" do
      # 2026-06-12 is a Friday; the 10th weekly occurrence is 2026-08-14.
      expect(description_for(starts_at: "2026-06-12 18:00", rule: IceCube::Rule.weekly.count(10)))
        .to eq("Weekly on Fridays at 6:00pm until Aug 14 2026")
    end

    it "omits the time for all-day recurring events" do
      expect(description_for(starts_at: "2026-06-08 00:00", rule: IceCube::Rule.weekly, all_day: true))
        .to eq("Weekly on Mondays")
    end
  end

  describe "#timespan" do
    let(:eventlet) do
      create(:eventlet, calendar: calendar, starts_at: "2026-06-08 14:00", ends_at: "2026-06-08 15:30")
    end

    it "formats the start and end on the same day" do
      expect(eventlet.decorate.timespan).to match(/Jun 0?8 2026.*2:00pm.*3:30pm/)
    end
  end
end

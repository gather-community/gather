# frozen_string_literal: true

require "rails_helper"

describe Work::PeriodDecorator do
  describe "#date_range" do
    def range(starts_on, ends_on)
      Work::Period.new(starts_on: Date.parse(starts_on), ends_on: Date.parse(ends_on)).decorate.date_range
    end

    context "on month boundaries" do
      it "shows a single month and year for one month" do
        expect(range("2026-01-01", "2026-01-31")).to eq("Jan 2026")
      end

      it "suppresses days for a span within one year" do
        expect(range("2026-01-01", "2026-04-30")).to eq("Jan–Apr 2026")
      end

      it "shows both years across a year boundary" do
        expect(range("2026-12-01", "2027-01-31")).to eq("Dec 2026–Jan 2027")
      end
    end

    context "not on month boundaries" do
      it "shows days with the year once for a span within one year" do
        expect(range("2026-01-15", "2026-04-10")).to eq("Jan 15–Apr 10 2026")
      end

      it "shows days and both years across a year boundary" do
        expect(range("2026-12-15", "2027-01-10")).to eq("Dec 15 2026–Jan 10 2027")
      end
    end
  end
end

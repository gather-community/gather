# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::FixedStartTimeRule do
  describe "#check" do
    let(:event) { Calendars::Event.new }
    let(:rule) { described_class.new(value: Time.zone.parse("12:00:00")) }

    it "passes on match" do
      event.starts_at = Time.zone.parse("2016-01-01 12:00pm")
      expect(rule.check(event)).to be(true)
    end

    it "fails on no match" do
      event.starts_at = Time.zone.parse("2016-01-01 12:00am")
      expect(rule.check(event)).to eq([:starts_at, "Must be 12:00pm"])
    end
  end
end

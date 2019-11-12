# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::MaxLengthMinutesRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:rule) { described_class.new(value: 30) }
    before { reservation.starts_at = Time.zone.parse("2016-01-30 6:00pm") }

    it "passes with acceptable length" do
      reservation.ends_at = Time.zone.parse("2016-01-30 6:30pm")
      expect(rule.check(reservation)).to be(true)
    end

    it "fails for too long event" do
      reservation.ends_at = Time.zone.parse("2016-01-30 6:31pm")
      expect(rule.check(reservation)).to eq([:ends_at, "Can be at most 30 minutes after start time"])
    end
  end
end

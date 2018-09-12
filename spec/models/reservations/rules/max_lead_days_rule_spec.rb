# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::MaxLeadDaysRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:rule) { described_class.new(value: 30) }
    before { Timecop.freeze(Time.zone.parse("2016-01-01 3:00pm")) }
    after { Timecop.return }

    it "passes with acceptable lead days" do
      reservation.starts_at = Time.zone.parse("2016-01-30 6:00pm")
      expect(rule.check(reservation)).to be true
    end

    it "passes for an event in the past" do
      reservation.starts_at = Time.zone.parse("2015-12-01 6:00pm")
      expect(rule.check(reservation)).to be true
    end

    it "fails for event too far in future" do
      reservation.starts_at = Time.zone.parse("2016-02-01 6:00pm")
      expect(rule.check(reservation)).to eq [:starts_at, "Can be at most 30 days in the future"]
    end
  end
end

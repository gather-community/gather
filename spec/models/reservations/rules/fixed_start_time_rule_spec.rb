# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::FixedStartTimeRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:rule) { described_class.new(value: Time.zone.parse("12:00:00")) }

    it "passes on match" do
      reservation.starts_at = Time.zone.parse("2016-01-01 12:00pm")
      expect(rule.check(reservation)).to be true
    end

    it "fails on no match" do
      reservation.starts_at = Time.zone.parse("2016-01-01 12:00am")
      expect(rule.check(reservation)).to eq [:starts_at, "Must be 12:00pm"]
    end
  end
end

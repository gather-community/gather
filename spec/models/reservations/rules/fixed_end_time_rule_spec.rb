# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::FixedEndTimeRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:rule) { described_class.new(value: Time.zone.parse("18:00:00")) }

    it "passes on match" do
      reservation.ends_at = Time.zone.parse("2016-01-01 6:00pm")
      expect(rule.check(reservation)).to be(true)
    end

    it "fails on no match" do
      reservation.ends_at = Time.zone.parse("2016-01-01 6:01pm")
      expect(rule.check(reservation)).to eq([:ends_at, "Must be  6:00pm"])
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::RequiresKindRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:rule) { described_class.new(value: true) }

    it "should pass if reservation has kind" do
      reservation.kind = "personal"
      expect(rule.check(reservation)).to be true
    end

    it "should fail if reservation has no kind" do
      expect(rule.check(reservation)).to eq [:kind, "can't be blank"]
    end
  end
end

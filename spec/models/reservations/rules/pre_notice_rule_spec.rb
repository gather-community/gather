# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::PreNoticeRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:rule) { described_class.new(value: "Foo bar") }

    it "should always pass" do
      expect(rule.check(reservation)).to be true
    end
  end
end

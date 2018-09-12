# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::MaxMinutesPerYearRule do
  describe "#check" do
    let(:resource1) { create(:resource, name: "Foo Room") }
    let(:resource2) { create(:resource, name: "Bar Room") }
    let(:resource3) { create(:resource, name: "Baz Room") }
    let(:household) { create(:household) }
    let(:user1) { create(:user, household: household) }
    let(:user2) { create(:user, household: household) }

    # Create 5 hours total reservations for resources 1,2,&3 for household.
    let!(:reservation1) do
      create(:reservation, reserver: user1, resource: resource1, kind: "Special",
                           starts_at: "2016-01-01 12:00", ends_at: "2016-01-01 13:00")
    end
    let!(:reservation2) do
      create(:reservation, reserver: user2, resource: resource2, kind: "Personal",
                           starts_at: "2016-01-03 12:00", ends_at: "2016-01-03 13:00")
    end
    let!(:reservation3) do
      create(:reservation, reserver: user2, resource: resource1,
                           starts_at: "2016-01-08 9:00", ends_at: "2016-01-08 10:00")
    end
    let!(:reservation4) do
      create(:reservation, reserver: user2, resource: resource1, kind: "Official",
                           starts_at: "2016-01-11 13:00", ends_at: "2016-01-11 14:00")
    end
    let!(:reservation5) do
      create(:reservation, reserver: user1, resource: resource3,
                           starts_at: "2016-01-11 13:00", ends_at: "2016-01-11 14:00")
    end

    let(:reservation) { Reservations::Reservation.new(reserver: user1, starts_at: "2016-01-30 6:00pm") }
    let(:rule) do
      described_class.new(value: 180, resources: [resource1, resource2], kinds: %w[Personal Special],
                          community: default_community)
    end

    # Most functionality is in the parent class and covered by max_days_per_year_spec
    # This one covers just the error message formatting and minutes unit.

    it "should work for event 1 hour long" do
      reservation.ends_at = Time.zone.parse("2016-01-30 7:00pm")
      expect(rule.check(reservation)).to be true
    end

    it "should fail for event 2 hours long" do
      reservation.ends_at = Time.zone.parse("2016-01-30 8:00pm")
      expect(rule.check(reservation)).to eq [:base, "You can book at most 3 hours of Personal/Special "\
        "Foo Room/Bar Room events per year and you have already booked 2 hours"]
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::MaxDaysPerYearRule do
  describe "#check" do
    let(:resource1) { create(:resource, name: "Foo Room") }
    let(:resource2) { create(:resource, name: "Bar Room") }
    let(:resource3) { create(:resource, name: "Baz Room") }
    let(:household) { create(:household) }
    let(:user1) { create(:user, household: household) }
    let(:user2) { create(:user, household: household) }

    # Create 110.5 hours total (8 days) reservations for resources 1,2,&3 for household.
    let!(:reservation1) do
      # 8 hours
      create(:reservation, reserver: user1, resource: resource1, kind: "Special",
                           starts_at: "2016-01-01 12:00", ends_at: "2016-01-01 20:00")
    end
    let!(:reservation2) do
      # 26 hours (2 days)
      create(:reservation, reserver: user2, resource: resource2, kind: "Personal",
                           starts_at: "2016-01-03 12:00", ends_at: "2016-01-04 14:00")
    end
    let!(:reservation3) do
      # 3.5 hours
      create(:reservation, reserver: user2, resource: resource1,
                           starts_at: "2016-01-08 9:00", ends_at: "2016-01-08 12:30")
    end
    let!(:reservation4) do
      # 70 hours (3 days)
      create(:reservation, reserver: user2, resource: resource1, kind: "Official",
                           starts_at: "2016-01-11 13:00", ends_at: "2016-01-14 11:00")
    end
    let!(:reservation5) do
      # 3 hours
      create(:reservation, reserver: user1, resource: resource3,
                           starts_at: "2016-01-11 13:00", ends_at: "2016-01-11 16:00")
    end

    let(:reservation) { Reservations::Reservation.new(reserver: user1, starts_at: "2016-01-30 6:00pm") }

    context "rule with kinds and resources" do
      let(:rule) do
        described_class.new(value: 4, resources: [resource1, resource2], kinds: %w[Personal Special],
                            community: default_community)
      end

      it "should work for event 1 hour long" do
        reservation.ends_at = Time.zone.parse("2016-01-30 7:00pm")
        expect(rule.check(reservation)).to be true
      end

      it "should fail for event 2 days long" do
        reservation.ends_at = Time.zone.parse("2016-01-31 9:00pm")
        expect(rule.check(reservation)).to eq [:base, "You can book at most 4 days of Personal/Special "\
          "Foo Room/Bar Room events per year and you have already booked 3 days"]
      end
    end

    context "rule with resources only" do
      let(:rule) do
        described_class.new(value: max_days, resources: [resource1, resource2], community: default_community)
      end

      context "with max 9 days per year" do
        let(:max_days) { 9 }

        it "should work for event 2 days long" do
          reservation.ends_at = Time.zone.parse("2016-02-01 12:00pm")
          expect(rule.check(reservation)).to be true
        end

        it "should fail for event 3 days long" do
          reservation.ends_at = Time.zone.parse("2016-02-01 7:30pm")
          expect(rule.check(reservation)).to eq [:base, "You can book at most 9 days "\
            "of Foo Room/Bar Room events per year and you have already booked 7 days"]
        end
      end

      context "with max 7 days per year" do
        let(:max_days) { 7 }

        it "should fail for even very short event" do
          reservation.ends_at = Time.zone.parse("2016-01-30 6:30pm")
          expect(rule.check(reservation)).to eq [:base, "You can book at most 7 days "\
            "of Foo Room/Bar Room events per year and you have already booked 7 days"]
        end
      end
    end

    context "rule with no resources or kinds" do
      let(:rule) do
        described_class.new(value: 9, resources: nil, kinds: nil, community: default_community)
      end

      it "should work for event 1 hour long" do
        reservation.ends_at = Time.zone.parse("2016-01-30 7:00pm")
        expect(rule.check(reservation)).to be true
      end

      it "should fail for event 2 days long" do
        reservation.ends_at = Time.zone.parse("2016-01-31 9:00pm")
        expect(rule.check(reservation)).to eq [:base, "You can book at most 9 days of events "\
          "per year and you have already booked 8 days"]
      end
    end
  end
end

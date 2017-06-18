require 'rails_helper'

RSpec.describe Reservation::Rule, type: :model do
  describe "check" do
    let(:reservation) { Reservation::Reservation.new }

    describe "fixed_start_time" do
      let(:rule) { Reservation::Rule.new(name: :fixed_start_time, value: Time.zone.parse("12:00:00")) }

      it "passes on match" do
        reservation.starts_at = Time.zone.parse("2016-01-01 12:00pm")
        expect(rule.check(reservation)).to be true
      end

      it "fails on no match" do
        reservation.starts_at = Time.zone.parse("2016-01-01 12:00am")
        expect(rule.check(reservation)).to eq [:starts_at, "Must be 12:00pm"]
      end
    end

    describe "fixed_end_time" do
      let(:rule) { Reservation::Rule.new(name: :fixed_end_time, value: Time.zone.parse("18:00:00")) }

      it "passes on match" do
        reservation.ends_at = Time.zone.parse("2016-01-01 6:00pm")
        expect(rule.check(reservation)).to be true
      end

      it "fails on no match" do
        reservation.ends_at = Time.zone.parse("2016-01-01 6:01pm")
        expect(rule.check(reservation)).to eq [:ends_at, "Must be  6:00pm"]
      end
    end

    describe "max_lead_days" do
      let(:rule) { Reservation::Rule.new(name: :max_lead_days, value: 30) }
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

    describe "max_length_minutes" do
      let(:rule) { Reservation::Rule.new(name: :max_length_minutes, value: 30) }
      before { reservation.starts_at = Time.zone.parse("2016-01-30 6:00pm") }

      it "passes with acceptable length" do
        reservation.ends_at = Time.zone.parse("2016-01-30 6:30pm")
        expect(rule.check(reservation)).to be true
      end

      it "fails for too long event" do
        reservation.ends_at = Time.zone.parse("2016-01-30 6:31pm")
        expect(rule.check(reservation)).to eq [:ends_at, "Can be at most 30 minutes after start time"]
      end
    end

    describe "yearly limits" do
      let(:resource1) { create(:resource) }
      let(:resource2) { create(:resource) }
      let(:household) { create(:household) }
      let(:user1) { create(:user, household: household) }
      let(:user2) { create(:user, household: household) }
      let(:protocol) { create(:reservation_protocol, resources: [resource1, resource2]) }

      # Create 107.5 hours total (7 days) reservations for resources 1&2 for household.
      let!(:reservation1) { create(:reservation, reserver: user1, resource: resource1,
        starts_at: "2016-01-01 12:00", ends_at: "2016-01-01 20:00") } # 8 hours
      let!(:reservation2) { create(:reservation, reserver: user2, resource: resource2,
        starts_at: "2016-01-03 12:00", ends_at: "2016-01-04 14:00") } # 26 hours (2 days)
      let!(:reservation3) { create(:reservation, reserver: user2, resource: resource1,
        starts_at: "2016-01-08 9:00", ends_at: "2016-01-08 12:30") } # 3.5 hours
      let!(:reservation4) { create(:reservation, reserver: user2, resource: resource1,
        starts_at: "2016-01-11 13:00", ends_at: "2016-01-14 11:00") } # 70 hours (3 days)

      describe "max_days_per_year" do
        let(:rule) do
          Reservation::Rule.new(name: :max_days_per_year, value: max_days, protocol: protocol)
        end

        before do
          reservation.reserver = user1
          reservation.starts_at = Time.zone.parse("2016-01-30 6:00pm")
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
              "per year and you have already booked 7 days"]
          end
        end

        context "with max 7 days per year" do
          let(:max_days) { 7 }

          it "should fail for even very short event" do
            reservation.ends_at = Time.zone.parse("2016-01-30 6:30pm")
            expect(rule.check(reservation)).to eq [:base, "You have already reached "\
              "your yearly limit of 7 days for this resource"]
          end
        end
      end

      describe "max_minutes_per_year" do
        let(:rule) do
          Reservation::Rule.new(name: :max_minutes_per_year,
            value: max_hours.hours / 60, protocol: protocol)
        end

        before do
          reservation.reserver = user1
          reservation.starts_at = Time.zone.parse("2016-01-30 6:00pm")
        end

        context "with max 110 hours per year" do
          let(:max_hours) { 110 }

          it "should pass with short reservation" do
            reservation.ends_at = Time.zone.parse("2016-01-30 7:00pm")
            expect(rule.check(reservation)).to be true
          end

          it "should pass with exactly right size reservation" do
            reservation.ends_at = Time.zone.parse("2016-01-30 8:30pm")
            expect(rule.check(reservation)).to be true
          end

          it "should fail with longer reservation" do
            reservation.ends_at = Time.zone.parse("2016-01-30 8:31pm")
            expect(rule.check(reservation)).to eq [:base, "You can book at most "\
              "4 days 14 hours per year and you have already booked 4 days 11 hours 30 minutes"]
          end
        end

        context "with max 37.5 hours per year" do
          let(:max_hours) { 107.5 }

          it "even a short reservation should fail" do
            reservation.ends_at = Time.zone.parse("2016-01-30 6:15pm")
            expect(rule.check(reservation)).to eq [:base, "You have already reached "\
              "your yearly limit of 4 days 11 hours 30 minutes for this resource"]
          end
        end
      end
    end

    describe "requires_kind" do
      let(:rule) { Reservation::Rule.new(name: :requires_kind, value: true) }

      it "should pass if reservation has kind" do
        reservation.kind = "personal"
        expect(rule.check(reservation)).to be true
      end

      it "should fail if reservation has no kind" do
        expect(rule.check(reservation)).to eq [:kind, "can't be blank"]
      end
    end

    describe "other_communities" do
      let(:resource) { create(:resource, community: create(:community)) }
      let(:household1) { create(:household, community: resource.community) }
      let(:insider) { create(:user, household: household1) }
      let(:outsider) { create(:user) }
      let(:outsider2) { create(:user) }
      let(:protocol) { create(:reservation_protocol, resources: [resource]) }
      let(:rule) { Reservation::Rule.new(name: :other_communities, value: value, protocol: protocol) }

      shared_examples_for "insiders only" do
        it "should pass for insider" do
          reservation.reserver = insider
          expect(rule.check(reservation)).to be true
        end

        it "should fail for outsider even with sponsor" do
          reservation.reserver = outsider
          reservation.sponsor = insider
          expect(rule.check(reservation)).to eq [:base,
            "Residents from other communities may not make reservations"]
        end
      end

      context "forbidden" do
        let(:value) { "forbidden" }
        it_behaves_like "insiders only"
      end

      context "read_only" do
        let(:value) { "read_only" }
        it_behaves_like "insiders only"
      end

      context "sponsor" do
        let(:value) { "sponsor" }

        it "should pass if insider has no sponsor" do
          reservation.reserver = insider
          expect(rule.check(reservation)).to be true
        end

        it "should pass if outsider has sponsor from community" do
          reservation.reserver = outsider
          reservation.sponsor = insider
          expect(rule.check(reservation)).to be true
        end

        it "should fail if outsider has sponsor from outside community" do
          reservation.reserver = outsider
          reservation.sponsor = outsider2
          expect(rule.check(reservation)).to eq [:sponsor_id,
            "You must have a sponsor from #{resource.community.name}"]
        end

        it "should fail if outsider has no sponsor" do
          reservation.reserver = outsider
          expect(rule.check(reservation)).to eq [:sponsor_id,
            "You must have a sponsor from #{resource.community.name}"]
        end
      end
    end

    describe "pre_notice" do
      let(:rule) { Reservation::Rule.new(name: :pre_notice, value: "Foo bar") }

      it "should always pass" do
        expect(rule.check(reservation)).to be true
      end
    end
  end
end

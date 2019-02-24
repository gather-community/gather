require "rails_helper"

describe Reservations::Reservation do
  let(:resource) { create(:resource) }
  let(:resource2) { create(:resource) }

  describe "no_overlap" do
    let!(:existing_reservation) { create(:reservation, resource: resource,
      starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 15:00") }
    let(:reservation) { Reservations::Reservation.new(resource: resource) }

    it "should not set error if no overlap on left" do
      reservation.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:00")
      expect_no_error(:no_overlap)
    end

    it "should not set error if no overlap on right" do
      reservation.assign_attributes(starts_at: "2016-04-07 15:00", ends_at: "2016-04-07 15:30")
      expect_no_error(:no_overlap)
    end

    it "should set error if partial overlap on left" do
      reservation.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 13:01")
      expect_overlap_error
    end

    it "should set error if partial overlap on right" do
      reservation.assign_attributes(starts_at: "2016-04-07 14:59", ends_at: "2016-04-07 15:30")
      expect_overlap_error
    end

    it "should set error if full overlap" do
      reservation.assign_attributes(starts_at: "2016-04-07 12:00", ends_at: "2016-04-07 15:30")
      expect_overlap_error
    end

    it "should set error if interior overlap" do
      reservation.assign_attributes(starts_at: "2016-04-07 14:30", ends_at: "2016-04-07 14:45")
      expect_overlap_error
    end

    def expect_overlap_error
      reservation.send(:no_overlap)
      expect(reservation.errors[:base]).to eq ["This reservation overlaps an existing one"]
    end
  end

  describe "apply_rules" do
    context "with no protocols" do
      let(:reservation) { Reservations::Reservation.new(resource: resource) }

      it "should not set error" do
        expect_no_error(:apply_rules)
      end
    end

    context "with a protocol" do
      let!(:protocol) { create(:reservation_protocol, resources: [resource2], requires_kind: true) }
      let(:reservation) { Reservations::Reservation.new(resource: resource2) }

      it "should set an error if applicable" do
        reservation.send(:apply_rules)
        expect(reservation.errors[:kind]).to eq ["can't be blank"]
      end
    end

    context "with missing starts_at" do
      let!(:protocol) { create(:reservation_protocol, resources: [resource2], max_lead_days: 30) }
      let(:reservation) { Reservations::Reservation.new(resource: resource2) }

      it "should not apply rules since doing so would cause problems" do
        reservation.save
        expect(reservation.errors[:starts_at]).to eq ["can't be blank"]
      end
    end
  end

  describe "meal reservation handler interactions" do
    let(:meal) { create(:meal, resources: [create(:resource)]) }
    let(:reservation) { meal.reservations.first }

    before do
      meal.build_reservations
      meal.save!
    end

    it "should call validate_reservation and then sync_resourcings" do
      reservation.starts_at += 1.minute
      expect(meal.reservation_handler).to receive(:validate_reservation).with(reservation)
      expect(meal.reservation_handler).to receive(:sync_resourcings).with(reservation)
      reservation.save!
    end
  end

  def expect_no_error(method)
    reservation.send(method)
    expect(reservation.errors).to be_empty
  end
end

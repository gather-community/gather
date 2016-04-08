require 'rails_helper'

RSpec.describe Reservation::Reservation, type: :model do
  let(:resource) { create(:resource) }
  let(:resource2) { create(:resource) }

  describe "no_overlap" do
    let!(:existing_reservation) { create(:reservation, resource: resource,
      starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 15:00") }
    let(:reservation) { Reservation::Reservation.new(resource: resource) }

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
      let(:reservation) { Reservation::Reservation.new(resource: resource) }

      it "should not set error" do
        expect_no_error(:apply_rules)
      end
    end

    context "with a protocol" do
      let!(:protocol) { create(:reservation_protocol, resources: [resource2], requires_kind: true) }
      let(:reservation) { Reservation::Reservation.new(resource: resource2) }

      it "should set an error if applicable" do
        reservation.send(:apply_rules)
        expect(reservation.errors[:kind]).to eq ["can't be blank"]
      end
    end
  end

  def expect_no_error(method)
    reservation.send(method)
    expect(reservation.errors).to be_empty
  end
end

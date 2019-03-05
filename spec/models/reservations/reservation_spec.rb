# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Reservations::Reservation, type: :model) do
  let(:resource) { create(:resource) }
  let(:resource2) { create(:resource) }

  describe "no_overlap" do
    let!(:existing_reservation) do
      create(:reservation, resource: resource,
                           starts_at: "2016-04-07 13:00", ends_at: "2016-04-07 15:00")
    end
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
      expect(reservation.errors[:base]).to eq(["This reservation overlaps an existing one"])
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
        expect(reservation.errors[:kind]).to eq(["can't be blank"])
      end
    end

    context "with missing starts_at" do
      let!(:protocol) { create(:reservation_protocol, resources: [resource2], max_lead_days: 30) }
      let(:reservation) { Reservations::Reservation.new(resource: resource2) }

      it "should not apply rules since doing so would cause problems" do
        reservation.save
        expect(reservation.errors[:starts_at]).to eq(["can't be blank"])
      end
    end
  end

  describe "other validations" do
    describe "can't change start time on not-just-created reservation after it begins" do
      let(:ends_at) { starts_at + 1.hour }
      subject(:reservation) do
        create(:reservation, created_at: created_at, starts_at: starts_at, ends_at: ends_at).tap do |r|
          r.starts_at += 10.minutes # Attempt to change the start time.
        end
      end

      context "just-created reservation with start time in past" do
        let(:created_at) { 5.minutes.ago }
        let(:starts_at) { 1.hour.ago }
        it { is_expected.to be_valid }
      end

      context "not-just-created reservation" do
        let(:created_at) { 2.hours.ago }

        context "start time in future" do
          let(:starts_at) { 1.hour.from_now }
          it { is_expected.to be_valid }
        end

        context "start time in past" do
          let(:starts_at) { 5.minutes.ago }
          it { is_expected.to have_errors(starts_at: "can't be changed after reservation begins") }
        end
      end
    end

    describe "can't change end time to a time in the past on not-just-created reservation" do
      let(:starts_at) { 30.minutes.ago }
      let(:ends_at) { starts_at + 1.hour }
      subject(:reservation) do
        create(:reservation, created_at: created_at, starts_at: starts_at, ends_at: ends_at).tap do |r|
          r.ends_at = new_ends_at
        end
      end

      context "just-created reservation" do
        let(:created_at) { 5.minutes.ago }
        let(:new_ends_at) { Time.current - 1.minute }
        it { is_expected.to be_valid }
      end

      context "not-just-created reservation" do
        let(:created_at) { 2.hours.ago }

        context "new end time in future" do
          let(:new_ends_at) { Time.current + 1.minute }
          it { is_expected.to be_valid }
        end

        context "new end time in past" do
          let(:new_ends_at) { Time.current - 1.minute }
          it { is_expected.to have_errors(ends_at: "can't be changed to a time in the past") }
        end
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

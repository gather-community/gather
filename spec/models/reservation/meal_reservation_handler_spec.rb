require 'rails_helper'

RSpec.describe Reservation::MealReservationHandler, type: :model do
  let(:community) { default_community }
  let(:resources) { create_list(:resource, 2) }
  let(:meal) { build(:meal, :with_menu, host_community: community, title: "A very very very long title",
    resources: resources, served_at: "2017-01-01 12:00") }
  let(:handler) { described_class.new(meal) }

  describe "sync" do
    before do
      # Set defaults to be used in first resourcing.
      community.settings.reservations.meals.default_prep_time = 90
      community.settings.reservations.meals.default_total_length = 210
      community.save!

      # Set custom times for second resourcing.
      meal.resourcings[1].prep_time = 60
      meal.resourcings[1].total_length = 90
      handler.sync
    end

    context "with clear calendars" do
      it "should initialize reservations on both resources" do
        reservations = meal.reservations
        expect(reservations.map(&:resource)).to contain_exactly(*resources)
        expect(reservations.map(&:starts_at)).to eq [
          Time.zone.parse("2017-01-01 10:30"),
          Time.zone.parse("2017-01-01 11:00")
        ]
        expect(reservations.map(&:ends_at)).to eq [
          Time.zone.parse("2017-01-01 14:00"),
          Time.zone.parse("2017-01-01 12:30")
        ]
        expect(reservations.map(&:kind).uniq).to eq ["_meal"]
        expect(reservations.map(&:guidelines_ok).uniq).to eq ["1"]
        expect(reservations.map(&:reserver).uniq).to eq [meal.creator]
        expect(reservations[0].name).to eq "Meal: A very very ver..."
      end
    end

    context "on update" do
      before do
        meal.save!
        meal.update(served_at: "2017-01-01 13:00")
        described_class.new(meal).sync
        meal.save!
      end

      it "deletes and replaces previous reservations" do
        expect(Reservation::Reservation.count).to eq 2
        expect(meal.reservations.map(&:starts_at)).to eq [
          Time.zone.parse("2017-01-01 11:30"),
          Time.zone.parse("2017-01-01 12:00")
        ]
      end
    end
  end

  describe "validation" do
    let!(:conflicting_reservation) { create(:reservation, resource: resources[0],
      starts_at: "2017-01-01 11:00", ends_at: "2017-01-01 12:00") }

    before do
      handler.sync
      handler.validate
    end

    it "sets base error on meal" do
      expect(meal.errors[:base]).to eq [
        "The following error(s) occurred in making a #{resources[0].full_name} " \
          "reservation for this meal: This reservation overlaps an existing one."]
    end
  end
end

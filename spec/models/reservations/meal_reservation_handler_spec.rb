require 'rails_helper'

describe Reservations::MealReservationHandler do
  let(:community) { Defaults.community }
  let(:resources) { create_list(:resource, 2) }
  let(:meal) { build(:meal, :with_menu, community: community, title: "A very very very long title",
    resources: resources, served_at: "2017-01-01 12:00") }
  let(:handler) { described_class.new(meal) }
  let(:handler2) { described_class.new(meal) }

  before do
    community.settings.reservations.meals.default_prep_time = 90
    community.settings.reservations.meals.default_total_time = 210
    community.save!
  end

  describe "build_reservations" do
    before do
      # Set custom times for second resourcing.
      meal.resourcings[1].prep_time = 60
      meal.resourcings[1].total_time = 90
      handler.build_reservations
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
      end

      context "on resource change" do
        let(:resource2) { create(:resource) }

        it "should update reservation" do
          meal.resources = [resource2]
          handler.build_reservations
          meal.save!
          expect(meal.reservations.reload.first.resource).to eq resource2
          expect(meal.reservations.size).to eq 1
        end

        it "should handle validation errors" do
          # Create reservation that will conflict when meal resource changes
          meal_time = meal.served_at
          create(:reservation, resource: resource2,
            starts_at: meal_time, ends_at: meal_time + 30.minutes)

          meal.resources = [resource2]
          handler.build_reservations
          meal.save
          expect_overlap_error(resource2)
        end
      end

      context "on title change" do
        before do
          meal.reservations.first.update!(note: "Foo")
        end

        it "should update reservation and preserve unaffected fields" do
          meal.title = "Nosh time"
          handler.build_reservations
          meal.save!
          expect(meal.reservations.reload.first.name).to eq "Meal: Nosh time"
          expect(meal.reservations.first.note).to eq "Foo"
        end
      end

      context "on time change" do
        context "with no conflict" do
          before do
            meal.update(served_at: "2017-01-01 13:00")
            described_class.new(meal).build_reservations
            meal.save!
          end

          it "should delete and replace previous reservations" do
            expect(Reservations::Reservation.count).to eq 2
            expect(meal.reservations.map(&:starts_at)).to eq [
              Time.zone.parse("2017-01-01 11:30"),
              Time.zone.parse("2017-01-01 12:00")
            ]
          end
        end

        context "with conflict" do
          before do
            new_meal_time = meal.served_at + 1.day
            create(:reservation, resource: resources[1],
              starts_at: new_meal_time, ends_at: new_meal_time + 30.minutes)
            meal.served_at = new_meal_time
            handler.build_reservations
          end

          it "should handle validation errors" do
            expect(meal).not_to be_valid
            expect_overlap_error(resources[1])
          end
        end
      end
    end
  end

  describe "validate_meal" do
    let!(:conflicting_reservation) { create(:reservation, resource: resources[0],
      starts_at: "2017-01-01 11:00", ends_at: "2017-01-01 12:00") }

    before do
      handler.build_reservations
      handler.validate_meal
    end

    it "sets base error on meal" do
      expect_overlap_error(resources[0])
    end
  end

  describe "validate_reservation" do
    let(:reservation) { meal.reload.reservations[0] }

    before do
      handler.build_reservations
      meal.save!
    end

    context "with valid change" do
      before do
        reservation.starts_at += 30.minutes
        reservation.ends_at += 15.minutes
        handler2.validate_reservation(reservation)
      end

      it "should not set error" do
        expect(reservation.errors.any?).to be false
      end
    end

    context "with change that moves start time after served_at" do
      before do
        reservation.starts_at = meal.served_at + 15.minutes
        handler2.validate_reservation(reservation)
      end

      it "should set error" do
        expect(reservation.errors[:starts_at]).to eq ["must be at or before the meal time (12:00pm)"]
        expect(reservation.errors[:ends_at]).to eq []
      end
    end

    context "with change that moves end time before served_at" do
      before do
        reservation.ends_at = meal.served_at - 15.minutes
        handler2.validate_reservation(reservation)
      end

      it "should set error" do
        expect(reservation.errors[:starts_at]).to eq []
        expect(reservation.errors[:ends_at]).to eq ["must be after the meal time (12:00pm)"]
      end
    end

    context "with reservation with nil starts_at" do
      it "should not error" do
        reservation.starts_at = nil
        handler2.validate_reservation(reservation)
      end
    end

    context "with reservation with nil ends_at" do
      it "should not error" do
        reservation.ends_at = nil
        handler2.validate_reservation(reservation)
      end
    end

    context "with meal with nil served_at" do
      it "should not error" do
        meal.served_at = nil
        handler2.validate_reservation(reservation)
      end
    end
  end

  describe "sync_resourcings" do
    let(:reservation) { meal.reload.reservations[0] }

    before do
      handler.build_reservations
      meal.save!
      reservation.starts_at += 30.minutes
      reservation.ends_at += 15.minutes
      handler2.sync_resourcings(reservation)
    end

    it "should change the resourcing's prep time and total time" do
      rsng = meal.resourcings[0].reload
      expect(rsng.prep_time).to eq 60
      expect(rsng.total_time).to eq 195
    end
  end

  def expect_overlap_error(resource)
    expect(meal).not_to be_valid
    expect(meal.errors[:base]).to eq ["The following error(s) occurred in making a #{resource.name} "\
      "reservation for this meal: This reservation overlaps an existing one."]
  end
end

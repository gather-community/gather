require 'rails_helper'

RSpec.describe Meal, type: :model do
  describe "reservation interlock" do
    let(:resource) { create(:resource) }
    let(:meal) { build(:meal, :with_menu, title: "Yummy", resource: resource) }

    before do
      Settings.meal_reservation_default_length = 120 # mins
      Settings.meal_reservation_default_prep_time = 30 # mins
    end

    context "on create" do
      it "should create reservation with correct attributes" do
        meal.sync_reservation
        meal.save!
        expect(meal.reservation.persisted?).to be true
        expect(meal.reservation.name).to eq "Meal: Yummy"
        expect(meal.reservation.starts_at).to eq meal.served_at - 30.minutes
        expect(meal.reservation.ends_at).to eq meal.served_at + 90.minutes
        expect(meal.reservation.kind).to eq "_meal"
      end

      it "should handle reservation validation errors" do
        meal_time = meal.served_at
        create(:reservation, resource: resource, starts_at: meal_time, ends_at: meal_time + 30.minutes)
        meal.sync_reservation
        expect_overlap_error
      end
    end

    context "on update" do
      let(:resource2) { create(:resource) }

      before do
        meal.sync_reservation
        meal.save!
      end

      context "on resource change" do
        it "should update reservation" do
          meal.resource = resource2
          meal.sync_reservation
          meal.save!
          expect(meal.reservation.reload.resource).to eq resource2
        end

        it "should handle validation errors" do
          # Create reservation that will conflict when meal resource changes
          meal_time = meal.served_at
          create(:reservation, resource: resource2,
            starts_at: meal_time, ends_at: meal_time + 30.minutes)

          meal.resource = resource2
          meal.sync_reservation
          meal.save
          expect_overlap_error
        end
      end

      context "on title change" do
        it "should update reservation" do
          meal.title = "Nosh time"
          meal.sync_reservation
          meal.save!
          expect(meal.reservation.reload.name).to eq "Meal: Nosh time"
        end
      end

      context "on time change" do
        it "should update reservation" do
          meal.served_at = Time.now + 2.days
          meal.sync_reservation
          meal.save!
          expect(meal.reservation.reload.starts_at).to eq meal.served_at - 30.minutes
        end

        it "should handle validation errors" do
          # Create reservation that will conflict with the new meal time
          new_meal_time = meal.served_at + 1.day
          create(:reservation, resource: resource,
            starts_at: new_meal_time, ends_at: new_meal_time + 30.minutes)

          meal.served_at = new_meal_time
          meal.sync_reservation
          meal.save
          expect_overlap_error
        end
      end
    end

    context "on destroy" do
      before do
        meal.sync_reservation
        meal.save!
      end

      it "should destroy reservation" do
        meal.destroy
        expect(meal.reservation).to be_destroyed
      end
    end

    def expect_overlap_error
      expect(meal).not_to be_valid
      expect(meal.errors[:base]).to eq ["The following error(s) occurred in making a reservation for this"\
        " meal: This reservation overlaps an existing one."]
    end
  end
end

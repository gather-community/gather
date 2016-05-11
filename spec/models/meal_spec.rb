require 'rails_helper'

RSpec.describe Meal, type: :model do
  describe "reservation interlock" do
    let(:resources) { create_list(:resource, 2) }
    let(:meal) { build(:meal, :with_menu, title: "Yummy", resources: resources) }

    before do
      Settings.meal_reservation_default_length = 120 # mins
      Settings.meal_reservation_default_prep_time = 30 # mins
    end

    context "on create" do
      it "should create reservations with correct attributes" do
        meal.sync_reservations
        meal.save!
        resources.each_with_index do |res, i|
          expect(meal.reservations[i].resource).to eq res
          expect(meal.reservations[i].persisted?).to be true
          expect(meal.reservations[i].name).to eq "Meal: Yummy"
          expect(meal.reservations[i].starts_at).to eq meal.served_at - 30.minutes
          expect(meal.reservations[i].ends_at).to eq meal.served_at + 90.minutes
          expect(meal.reservations[i].kind).to eq "_meal"
        end
      end

      it "should handle reservation validation errors" do
        meal_time = meal.served_at
        create(:reservation, resource: resources[0], starts_at: meal_time, ends_at: meal_time + 30.minutes)
        meal.sync_reservations
        expect_overlap_error(resources[0])
      end
    end

    context "on update" do
      let(:resource2) { create(:resource) }

      before do
        meal.sync_reservations
        meal.save!
      end

      context "on resource change" do
        it "should update reservation" do
          meal.resources = [resource2]
          meal.sync_reservations
          meal.save!
          expect(meal.reservations(true).first.resource).to eq resource2
        end

        it "should handle validation errors" do
          # Create reservation that will conflict when meal resource changes
          meal_time = meal.served_at
          create(:reservation, resource: resource2,
            starts_at: meal_time, ends_at: meal_time + 30.minutes)

          meal.resources = [resource2]
          meal.sync_reservations
          meal.save
          expect_overlap_error(resource2)
        end
      end

      context "on title change" do
        it "should update reservation" do
          meal.title = "Nosh time"
          meal.sync_reservations
          meal.save!
          expect(meal.reservations(true).first.name).to eq "Meal: Nosh time"
        end
      end

      context "on time change" do
        it "should update reservation" do
          meal.served_at = Time.now + 2.days
          meal.sync_reservations
          meal.save!
          expect(meal.reservations(true).first.starts_at).to eq meal.served_at - 30.minutes
        end

        it "should handle validation errors" do
          # Create reservation that will conflict with the new meal time
          new_meal_time = meal.served_at + 1.day
          create(:reservation, resource: resources[1],
            starts_at: new_meal_time, ends_at: new_meal_time + 30.minutes)

          meal.served_at = new_meal_time
          meal.sync_reservations
          meal.save
          expect_overlap_error(resources[1])
        end
      end
    end

    context "on destroy" do
      before do
        meal.sync_reservations
        meal.save!
      end

      it "should destroy reservation" do
        meal.destroy
        expect(meal.reservations).to be_empty
      end
    end

    def expect_overlap_error(resource)
      expect(meal).not_to be_valid
      expect(meal.errors[:base]).to eq ["The following error(s) occurred in making a #{resource.name} "\
        "reservation for this meal: This reservation overlaps an existing one."]
    end
  end
end

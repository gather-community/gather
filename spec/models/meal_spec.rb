# frozen_string_literal: true

require "rails_helper"

describe Meal, type: :model do
  describe "validations" do
    describe "resources" do
      it "fails if none" do
        meal = build(:meal, no_resources: true)
        expect(meal).not_to be_valid
        expect(meal.errors[:resources].join).to match /must choose at least one location/
      end

      it "succeeds if some" do
        meal = build(:meal)
        expect(meal).to be_valid
      end
    end

    describe "via meal reservation handler" do
      let(:meal) { build(:meal, resources: [create(:resource)]) }

      it "should call validate_meal on handler if reservations present" do
        meal.build_reservations
        expect(meal.reservation_handler).to receive(:validate_meal)
        meal.valid?
      end
    end
  end

  describe "menu_posted_at" do
    it "gets set automatically when menu entered on create" do
      meal = create(:meal, :with_menu)
      expect(meal.menu_posted_at).to be_within(1.second).of(Time.current)
    end

    it "gets set automatically when menu entered on update" do
      meal = create(:meal)
      expect(meal.menu_posted_at).to be_nil
      meal.update!(title: "Fish!", entrees: "Fish, obvs", allergen_none: true)
      expect(meal.menu_posted_at).to be_within(1.second).of(Time.current)
    end

    it "doesn't get set twice" do
      meal = create(:meal, :with_menu)
      Timecop.freeze(1.minute) do
        meal.update!(title: "Fish!")
        expect(meal.menu_posted_at).to be_within(1.second).of(1.minute.ago)
      end
    end
  end
end

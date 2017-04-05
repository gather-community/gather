require 'rails_helper'

RSpec.describe Meal, type: :model do
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
end

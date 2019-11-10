require "rails_helper"

describe Meals::Meal do
  let(:meal) { create(:meal) }

  describe "close!" do
    it "should close the meal" do
      meal.close!
      expect(meal.reload).to be_closed
    end
  end

  describe "reopen!" do
    it "should reopen the meal" do
      meal.close!
      meal.reopen!
      expect(meal.reload).to be_open
    end
  end

  describe "cancel!" do
    before do
      meal.build_reservations
      meal.save!
    end

    it "should cancel the meal and delete reservations" do
      expect(meal.reservations.count).to be > 0
      meal.cancel!
      expect(meal.reload).to be_cancelled
      expect(meal.reservations.count).to eq 0
    end
  end

  describe "full?" do
    it "should be true if spots left" do
      allow(meal).to receive(:spots_left).and_return(10)
      expect(meal).not_to be_full
    end
  end
end

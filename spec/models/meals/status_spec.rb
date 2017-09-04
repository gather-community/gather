require "rails_helper"

describe Meals::Status do
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
    it "should cancel the meal" do
      meal.cancel!
      expect(meal.reload).to be_cancelled
    end
  end

  describe "full?" do
    it "should be true if spots left" do
      allow(meal).to receive(:spots_left).and_return(10)
      expect(meal).not_to be_full
    end
  end
end

require "rails_helper"

describe Meals::Status do
  let(:meal) { create(:meal) }

  describe "close!" do
    it "should close the meal" do
      meal.close!
      expect(meal.reload).to be_closed
    end

    it "should error if meal already closed" do
      meal.close!
      expect { meal.close! }.to raise_error(ArgumentError)
    end
  end

  describe "reopen!" do
    it "should reopen the meal" do
      meal.close!
      meal.reopen!
      expect(meal.reload).to be_open
    end

    it "should error if meal already open" do
      expect { meal.reopen! }.to raise_error(ArgumentError)
    end
  end

  describe "full?" do
    it "should be true if spots left" do
      allow(meal).to receive(:spots_left).and_return(10)
      expect(meal).not_to be_full
    end

    it "should be false if no spots left" do
      allow(meal).to receive(:spots_left).and_return(0)
      expect(meal).to be_full
    end
  end

  describe "reopenable?" do
    before { meal.close! }

    it "should be true if day prior to meal" do
      Timecop.travel(meal.served_at - 1.day) do
        expect(meal).to be_reopenable
      end
    end

    it "should be true if after meal but same day" do
      Timecop.travel(meal.served_at + 1.minute) do
        expect(meal).to be_reopenable
      end
    end

    it "should be false if day after meal" do
      Timecop.travel(meal.served_at + 1.day) do
        expect(meal).not_to be_reopenable
      end
    end
  end

  describe "finalizable?" do
    before { meal.close! }

    it "should be false if day prior to meal" do
      Timecop.travel(meal.served_at - 1.day) do
        expect(meal).not_to be_finalizable
      end
    end

    it "should be true if after meal" do
      Timecop.travel(meal.served_at + 1.minute) do
        expect(meal).to be_finalizable
      end
    end
  end

  describe "new_signups_allowed?" do
    it "should be true if before meal and not closed or full" do
      Timecop.travel(meal.served_at - 1.day) do
        expect(meal).to be_new_signups_allowed
      end
    end
  end

  describe "signups_editable?" do
    it "should be true if before meal and not closed" do
      allow(meal).to receive(:full?).and_return(true)
      Timecop.travel(meal.served_at - 1.day) do
        expect(meal).to be_new_signups_allowed
      end
    end
  end
end

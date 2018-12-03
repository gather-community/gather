# frozen_string_literal: true

require "rails_helper"

describe Signup do
  describe "with no signups" do
    context "on create" do
      let(:signup) { build(:signup) }

      it "should delete itself if all zeros" do
        expect(signup).not_to be_valid
        expect(signup.errors[:base].join).to match("must sign up at least")
      end
    end

    context "on update" do
      let(:signup) { create(:signup, adult_veg: 2) }

      it "should delete itself" do
        signup.update!(adult_veg: 0)
        expect(signup).to be_destroyed
      end
    end
  end

  describe "validation" do
    describe "dont_exceed_spots" do
      let(:meal) { create(:meal, capacity: 5) }
      # Need to use meal.id so that this instance of meal doesn't memoize spots_left.
      let!(:existing_signup) { create(:signup, meal_id: meal.id, adult_meat: 2, adult_veg: 0) }

      context "with new record" do
        # Need to reload meal because otherwise it doesn't know about existing_signup.
        let(:signup) { build(:signup, meal: meal.reload, adult_meat: 2, adult_veg: veg).tap(&:validate) }

        context "with just right" do
          let(:veg) { 1 }
          it { expect(signup).to be_valid }
        end

        context "with too many" do
          let(:veg) { 2 }
          it do
            expect(signup.errors[:base].join).to eq("Based on the number of spots remaining, "\
              "you can sign up a maximum of 3 people.")
          end
        end
      end

      context "with existing record" do
        # After this one is created there will be a total of 4 diners.
        let!(:signup) { create(:signup, meal: meal.reload, adult_meat: 2, adult_veg: 0) }

        before { signup.reload.update(adult_veg: veg) }

        context "with just right" do
          let(:veg) { 1 }
          it { expect(signup).to be_valid }
        end

        context "with too many" do
          let(:veg) { 2 }
          it do
            expect(signup.errors[:base].join).to eq("Based on the number of spots remaining, "\
              "you can sign up a maximum of 3 people.")
          end
        end
      end
    end
  end
end

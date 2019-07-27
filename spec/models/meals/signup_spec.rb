# frozen_string_literal: true

require "rails_helper"

describe Meals::Signup do
  describe "validation" do
    describe "dont_exceed_spots" do
      let(:meal) { create(:meal, capacity: 5) }
      # Need to use meal.id so that this instance of meal doesn't memoize spots_left.
      let!(:existing_signup) { create(:meal_signup, meal_id: meal.id, diner_count: 2) }

      context "with new record" do
        # Need to reload meal because otherwise it doesn't know about existing_signup.
        let(:signup) { build(:meal_signup, meal: meal.reload, diner_count: new_count).tap(&:validate) }

        context "with just right" do
          let(:new_count) { 3 }
          it { expect(signup).to be_valid }
        end

        context "with too many" do
          let(:new_count) { 4 }
          it do
            expect(signup.errors[:base].join).to eq("Based on the number of spots remaining, "\
              "you can sign up a maximum of 3 people.")
          end
        end
      end

      context "with existing record" do
        # After this one is created there will be a total of 4 diners due to one in outer block.
        let!(:signup) { create(:meal_signup, meal: meal.reload, diner_count: 2) }

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

    describe "no_dupe_types" do
      let(:formula) { create(:meal_formula, part_shares: [1, 0.5]) }
      let(:meal) { create(:meal, formula: formula) }
      subject(:signup) { build(:meal_signup, meal: meal, parts_attributes: parts_attributes, flag_zzz: true) }

      context "without dupe types" do
        let(:parts_attributes) do
          [{type_id: formula.types[0].id, count: 2}, {type_id: formula.types[1].id, count: 3}]
        end

        it { is_expected.to be_valid }
      end

      context "with dupe types" do
        let(:parts_attributes) do
          [{type_id: formula.types[0].id, count: 2}, {type_id: formula.types[0].id, count: 3}]
        end

        it { is_expected.to have_errors(base: "Please sign up each type only once") }
      end
    end
  end
end

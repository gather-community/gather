# frozen_string_literal: true

require "rails_helper"

describe Meals::Signup do
  describe "#total and #total_was" do
    context "with no signups" do
      subject(:signup) { build(:meal_signup, parts_attributes: {"0": {count: 0}}) }
      it do
        expect(signup.total).to eq(0)
        expect(signup.total_was).to eq(0)
      end
    end

    context "with new record" do
      subject(:signup) { build(:meal_signup, parts_attributes: {"0": {count: 1}, "1": {count: 2}}) }
      it do
        expect(signup.total).to eq(3)
        expect(signup.total_was).to eq(0)
      end
    end

    context "with existing record" do
      subject!(:signup) { create(:meal_signup, diner_counts: [1, 2]) }

      before do
        # Add, edit, and delete
        signup.assign_attributes(parts_attributes: {
          "0": {id: signup.parts[0].id, count: 4},
          "1": {id: signup.parts[1].id, _destroy: "1"},
          "2": {count: 8}
        })
      end

      it do
        expect(signup.total).to eq(12)
        expect(signup.total_was).to eq(3)
      end
    end
  end

  describe "validation" do
    describe "nonzero_signups_if_new" do
      context "with new record" do
        context "with zero signups" do
          subject(:signup) { build(:meal_signup) }
          it { is_expected.to have_errors(base: /must sign up at least/) }
        end

        context "with nonzero signups" do
          subject(:signup) { build(:meal_signup, diner_counts: [1]) }
          it { is_expected.to be_valid }
        end
      end

      # In this case the record will get destroyed so we don't worry about validations.
      context "with existing record being modified and zero signups" do
        subject(:signup) { create(:meal_signup, diner_counts: [1]).tap { |s| s.parts[0].update!(count: 0) } }
        context "with zero signups" do
          it { is_expected.to be_valid }
        end
      end
    end

    describe "dont_exceed_spots" do
      let(:meal) { create(:meal, capacity: 5) }
      # Need to use meal.id so that this instance of meal doesn't memoize spots_left.
      let!(:previous_signup) { create(:meal_signup, meal_id: meal.id, diner_counts: [2]) }

      context "with new record" do
        # Need to reload meal because otherwise it doesn't know about previous_signup.
        subject(:signup) { build(:meal_signup, meal: meal.reload, diner_counts: [new_count]) }

        context "with just the right number" do
          let(:new_count) { 3 }
          it { is_expected.to be_valid }
        end

        context "with too many" do
          let(:new_count) { 4 }
          it do
            is_expected.to have_errors(base: "Based on the number of spots remaining, " \
                                             "you can sign up a maximum of 3 people.")
          end
        end
      end

      context "with existing record being modified" do
        subject(:signup) { create(:meal_signup, meal: meal.reload, diner_counts: [1]) }

        before do
          signup.parts[0].count = new_count
        end

        context "with just the right number" do
          let(:new_count) { 3 }
          it { is_expected.to be_valid }
        end

        context "with too many" do
          let(:new_count) { 4 }
          it do
            is_expected.to have_errors(base: "Based on the number of spots remaining, " \
                                             "you can sign up a maximum of 3 people.")
          end
        end

        context "with capacity being previously exceeded somehow" do
          subject(:signup) { create(:meal_signup, meal: meal.reload, diner_counts: [3]) }

          before do
            # This change will put total at 8 despite capacity being 5.
            previous_signup.parts[0].update_column(:count, 5)

            # We update comments so that model will be dirty even if no change in diner count.
            signup.parts[0].count = new_count
            signup.comments = "new comment"
          end

          context "if not changing diner count" do
            let(:new_count) { 3 }
            it "should be valid even though capacity still exceeded since it's not this person's fault" do
              is_expected.to be_valid
            end
          end

          context "if increasing diner count" do
            let(:new_count) { 4 }
            it "should be invalid and report the previous signup count as the max" do
              is_expected.to have_errors(base: "Based on the number of spots remaining, " \
                                               "you can sign up a maximum of 3 people.")
            end
          end
        end
      end
    end
  end

  describe "no_dupe_types" do
    let(:formula) { create(:meal_formula, parts_attrs: [1, 0.5]) }
    let(:meal) { create(:meal, formula: formula) }
    subject(:signup) { build(:meal_signup, meal: meal, parts_attributes: parts_attributes) }

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

  describe "deletion on zero" do
    let(:formula) { create(:meal_formula, parts_attrs: [1, 0.5]) }
    let(:meal) { create(:meal, formula: formula) }
    subject(:signup) do
      create(:meal_signup, meal: meal, parts_attributes: parts_attributes)
    end

    context "on create" do
      # All zero case triggers validation, see above
      context "partial zero" do
        # Deliberately including same type_id twice.
        # Second should get ignored and not trigger unique validation.
        let(:parts_attributes) do
          [
            {type_id: formula.types[0].id, count: 2},
            {type_id: formula.types[1].id, count: 0},
            {type_id: formula.types[0].id, count: 0}
          ]
        end

        it "doesn't save zero part" do
          expect(Meals::Signup.find(signup.id).parts.map(&:count)).to eq([2])
        end
      end
    end

    context "on update" do
      let(:parts_attributes) do
        [{type_id: formula.types[0].id, count: 2}, {type_id: formula.types[1].id, count: 3}]
      end

      context "partial zero" do
        it "destroys zero part" do
          signup.reload.update!(parts_attributes:
            [{id: signup.parts[0].id, count: 0}, {id: signup.parts[1].id, count: 4}])
          expect(Meals::Signup.find(signup.id).parts.map(&:count)).to eq([4])
        end
      end

      context "all zero" do
        it "destroys signup" do
          signup.reload.update!(parts_attributes:
            [{id: signup.parts[0].id, count: 0}, {id: signup.parts[1].id, count: 0}])
          expect { signup.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end

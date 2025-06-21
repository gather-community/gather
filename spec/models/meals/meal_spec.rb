# frozen_string_literal: true

# == Schema Information
#
# Table name: meals
#
#  id              :integer          not null, primary key
#  allergens       :jsonb            not null
#  auto_close_time :datetime
#  capacity        :integer          not null
#  cluster_id      :integer          not null
#  community_id    :integer          not null
#  created_at      :datetime         not null
#  creator_id      :integer          not null
#  dessert         :text
#  entrees         :text
#  formula_id      :integer          not null
#  kids            :text
#  menu_posted_at  :datetime
#  no_allergens    :boolean          default(FALSE), not null
#  notes           :text
#  served_at       :datetime         not null
#  side            :text
#  status          :string           default("open"), not null
#  title           :string
#  updated_at      :datetime         not null
#
require "rails_helper"

describe Meals::Meal do
  describe "validations" do
    describe "auto_close_time" do
      context "with time in future" do
        subject(:meal) { build(:meal, auto_close_time: Time.current + 1.day) }
        it { is_expected.to be_valid }
      end

      context "with time too far in future" do
        subject(:meal) do
          build(:meal, status: status, served_at: Time.current + 7.days,
                       auto_close_time: Time.current + 8.days)
        end

        context "with open meal" do
          let(:status) { "open" }
          it { is_expected.to have_errors(auto_close_time: "must be between now and the meal time") }
        end

        context "with non-open meal" do
          let(:status) { "closed" }
          it { is_expected.to be_valid }
        end
      end

      context "with no served_at" do
        subject(:meal) do
          build(:meal, served_at: nil, auto_close_time: Time.current + 8.days)
        end
        it { is_expected.to have_errors(auto_close_time: nil, served_at: "can't be blank") }
      end

      context "with time in past" do
        subject(:meal) { build(:meal, auto_close_time: Time.current - 1.minute) }
        it { is_expected.to have_errors(auto_close_time: "must be between now and the meal time") }
      end
    end

    describe "via meal event handler" do
      let(:meal) { build(:meal, calendars: [create(:calendar)]) }

      it "should call validate_meal on handler if events present" do
        meal.build_events
        expect(meal.event_handler).to receive(:validate_meal)
        meal.valid?
      end
    end

    describe "signup uniqueness" do
      let(:hholds) { create_list(:household, 2) }
      subject(:meal) { build(:meal, signups: signups) }

      context "with unique signups" do
        let(:signups) do
          [
            build(:meal_signup, household_id: hholds[0].id, diner_counts: [2, 1]),
            build(:meal_signup, household_id: hholds[1].id, diner_counts: [2, 1])
          ]
        end
        it { is_expected.to be_valid }
      end

      context "with duplicate signups" do
        let(:signups) do
          [
            build(:meal_signup, household_id: hholds[0].id, diner_counts: [2, 1]),
            build(:meal_signup, household_id: hholds[1].id, diner_counts: [2, 1]),
            build(:meal_signup, household_id: hholds[0].id, diner_counts: [2, 1]),
            build(:meal_signup, household_id: hholds[0].id, diner_counts: [2, 1])
          ]
        end

        it do
          expect(meal).not_to be_valid
          expect(meal.signups[0]).to be_valid
          expect(meal.signups[1]).to be_valid
          expect(meal.signups[2].errors[:household_id].join).to match(/has already been taken/)
          expect(meal.signups[3].errors[:household_id].join).to match(/has already been taken/)
        end
      end
    end

    describe "enough capacity" do
      let!(:signup) { create(:meal_signup, diner_counts: [5]) }
      let(:meal) { signup.meal.tap { |m| m.signups.reload } }

      it "saves cleanly with enough capacity" do
        meal.update(capacity: 5)
        expect(meal).to be_valid
      end

      it "errors with not enough capacity" do
        meal.update(capacity: 4)
        expect(meal.errors[:capacity].join).to eq("must be at least 5 due to current signups")
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
      meal.update!(title: "Fish!", entrees: "Fish, obvs", no_allergens: true)
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

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    let!(:meal) { create(:meal) }
    let!(:signups) { create_list(:meal_signup, 2, meal: meal, diner_counts: [2, 1]) }
    let!(:cost) { create(:meal_cost, meal: meal) }

    before do
      meal.reload # Force associations to be recognized.
      meal.build_events
      meal.save!
    end

    context "unfinalized" do
      it "deletes cleanly" do
        meal.destroy
        expect { meal.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "finalized with transactions" do
      before do
        Meals::Finalizer.new(meal).finalize!
      end

      it "raises error" do
        expect { meal.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
      end
    end
  end
end

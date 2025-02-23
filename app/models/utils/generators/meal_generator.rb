# frozen_string_literal: true

module Utils
  module Generators
    # Generates fake meal data
    class MealGenerator < Generator
      attr_accessor :community, :data, :formula, :statement_gen, :locations, :creator, :households, :adults

      MONTHS = 5

      def initialize(community:, statement_gen:)
        self.community = community
        self.statement_gen = statement_gen
        self.data = load_yaml("meals/meals.yml")
      end

      def generate_seed_data
        roles = [
          Meals::Role.create!(
            community: community,
            count_per_meal: 1,
            title: "Head Cook",
            special: "head_cook",
            description: "Plans and supervises meal prep.",
            time_type: "date_only",
            reminders_attributes: [{rel_magnitude: 3, rel_unit_sign: "days_before"}]
          ),
          Meals::Role.create!(
            community: community,
            count_per_meal: 2,
            title: "Assistant Cook",
            description: "Helps with meal prep as directed by the head cook.",
            time_type: "date_time",
            shift_start: -120,
            shift_end: 0,
            reminders_attributes: [{rel_magnitude: 1, rel_unit_sign: "days_before"}]
          ),
          Meals::Role.create!(
            community: community,
            count_per_meal: 3,
            title: "Cleaner",
            description: "Cleans up after the meal.",
            time_type: "date_time",
            shift_start: 60,
            shift_end: 150,
            reminders_attributes: [{rel_magnitude: 1, rel_unit_sign: "days_before"}]
          )
        ]
        self.formula = create(:meal_formula,
                              community: community, roles: roles, is_default: true,
                              name: "Default Formula", meal_calc_type: "share",
                              parts_attrs: [{type: "Adult", share: "100%", portion: 1},
                                            {type: "Teen", share: "75%", portion: 0.75},
                                            {type: "Kid", share: "50%", portion: 0.5},
                                            {type: "Little Kid", share: "0%", portion: 0.25}])
      end

      def generate_samples
        load_objs
        create_meals
      end

      private

      def load_objs
        self.creator = User.adults.sample
        self.households = Household.all
        self.adults = User.adults.active.to_a
        self.locations = [
          Calendars::Calendar.find_by(name: "Kitchen"),
          Calendars::Calendar.find_by(name: "Dining Room")
        ]
      end

      def create_meals
        real_now = Time.zone.now

        # All but 1 month of meals should be in past.
        Timecop.freeze(((MONTHS - 1) * 30).days.ago.beginning_of_week.midnight) do
          MONTHS.times do |month|
            Timecop.freeze(month.months) do
              finalize_and_run_statements if month.positive? && Time.zone.now < real_now
              4.times do |week|
                create_meals_and_signups_for_week(week)
              end
            end
          end
        end
      end

      def finalize_and_run_statements
        Meals::Meal.where.not(status: "finalized").find_each do |meal|
          meal.update!(status: "finalized")
          meal.build_cost(
            ingredient_cost: (rand(10_000) / 100.0) + 32,
            pantry_cost: rand(1000) / 100.0,
            payment_method: Meals::Cost::PAYMENT_METHODS.sample,
            reimbursee: meal.head_cook
          )
          Meals::Finalizer.new(meal).finalize!
        end
        statement_gen.generate_samples
      end

      def create_meals_and_signups_for_week(week)
        [0, 4].each do |day|
          served_at = Time.zone.now + week.weeks + day.days + 18.hours
          datum = data.pop
          staff = adults.shuffle

          meal = build(:meal, datum.merge(
            formula: formula,
            calendars: locations,
            community: community,
            capacity: 80,
            head_cook: staff[0],
            asst_cooks: staff[1..2],
            cleaners: staff[3..4],
            served_at: served_at,
            creator: creator,
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
          meal.build_events
          meal.save!

          num_households = 5 + rand(households.size - 5)
          households.shuffle[0...num_households].each do |household|
            members = household.users.to_a
            create(:meal_signup, meal: meal, household: household,
                                 diner_counts: distribute_diners([members.size - rand(3), 1].max))
            break if meal.reload.full?
          end
        end
      end

      def distribute_diners(count)
        result = []
        left = count
        (formula.types.size - 1).times do
          result << rand(left + 1)
          left -= result.last
        end
        result << left
        result
      end
    end
  end
end

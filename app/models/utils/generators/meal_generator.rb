# frozen_string_literal: true

module Utils
  module Generators
    # Generates fake meal data
    class MealGenerator < Generator
      attr_accessor :community, :data, :roles, :formula, :statement_gen, :calendar_map, :locations, :creator,
        :households, :adults

      MONTHS = 5

      # The Kitchen and Dining Room, by their IDs in calendars/calendars.yml (see
      # CalendarGenerator#calendar_map).
      MEAL_CALENDAR_IDS = [116, 21].freeze

      def initialize(community:, statement_gen:, calendar_map:)
        self.community = community
        self.statement_gen = statement_gen
        self.calendar_map = calendar_map
        self.data = load_yaml("meals/meals.yml")
      end

      def generate_seed_data
        self.roles = [
          Meals::Role.create!(
            community: community,
            count_per_meal: 1,
            title: I18n.t("starter_content.meal_roles.head_cook.title"),
            special: "head_cook",
            description: I18n.t("starter_content.meal_roles.head_cook.description"),
            time_type: "date_only",
            reminders_attributes: [{rel_magnitude: 3, rel_unit_sign: "days_before"}]
          ),
          Meals::Role.create!(
            community: community,
            count_per_meal: 2,
            title: I18n.t("starter_content.meal_roles.assistant_cook.title"),
            description: I18n.t("starter_content.meal_roles.assistant_cook.description"),
            time_type: "date_time",
            shift_start: -120,
            shift_end: 0,
            reminders_attributes: [{rel_magnitude: 1, rel_unit_sign: "days_before"}]
          ),
          Meals::Role.create!(
            community: community,
            count_per_meal: 3,
            title: I18n.t("starter_content.meal_roles.cleaner.title"),
            description: I18n.t("starter_content.meal_roles.cleaner.description"),
            time_type: "date_time",
            shift_start: 60,
            shift_end: 150,
            reminders_attributes: [{rel_magnitude: 1, rel_unit_sign: "days_before"}]
          )
        ]
        self.formula = create(:meal_formula,
          community: community, roles: roles, is_default: true,
          name: I18n.t("starter_content.meal_formula"), meal_calc_type: "share",
          parts_attrs: [
            {type: meal_type(:adult), share: "100%", portion: 1},
            {type: meal_type(:teen), share: "75%", portion: 0.75},
            {type: meal_type(:kid), share: "50%", portion: 0.5},
            {type: meal_type(:little_kid), share: "0%", portion: 0.25}
          ])
        community.settings.meals.allergens = I18n.t("starter_content.allergens")
        community.save!
      end

      def generate_samples
        load_objs
        create_meals
      end

      private

      def meal_type(key)
        I18n.t("starter_content.meal_types.#{key}")
      end

      def load_objs
        self.creator = User.adults.sample
        self.households = Household.all
        self.adults = User.adults.active.to_a
        self.locations = calendar_map.values_at(*MEAL_CALENDAR_IDS)
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
            ingredient_cost: rand(10_000) / 100.0 + 32,
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

          meal = build(:meal,
            **sample_text(:meals, datum["key"], :title, *Meals::Meal::MENU_ITEMS.map(&:to_sym)),
            allergens: datum["allergens"].map { |key| I18n.t("sample_data.allergens.#{key}") },
            no_allergens: datum["allergens"].empty?,
            formula: formula,
            calendars: locations,
            community: community,
            capacity: 80,
            head_cook: false, # Assigned below, since the factory finds roles by their English titles.
            served_at: served_at,
            creator: creator,
            created_at: community.created_at,
            updated_at: community.updated_at)
          # Head cook, assistant cooks and cleaners, in the order of `roles`.
          [staff[0..0], staff[1..2], staff[3..4]].zip(roles).each do |workers, role|
            workers.each { |user| meal.assignments.build(role: role, user: user) }
          end
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

module Utils
  module FakeData
    class MealGenerator < Generator
      attr_accessor :community, :data, :formula, :statement_gen, :locations, :creator, :households, :adults

      MONTHS = 5

      def initialize(community:, statement_gen:)
        self.community = community
        self.statement_gen = statement_gen
        self.data = load_yaml("meals/meals.yml")
      end

      def generate
        load_objs
        self.formula = create(:meal_formula, community: community)
        create_meals
      end

      private

      def load_objs
        self.creator = User.adults.sample
        self.households = Household.all
        self.adults = User.adults.active.to_a
        self.locations = [
          Reservations::Resource.find_by(name: "Kitchen"),
          Reservations::Resource.find_by(name: "Dining Room")
        ]
      end

      def create_meals
        real_now = Time.zone.now

        # All but 1 month of meals should be in past.
        Timecop.freeze(((MONTHS - 1) * 30).days.ago.beginning_of_week.midnight) do
          MONTHS.times do |month|
            Timecop.freeze(month.months) do
              finalize_and_run_statements if month > 0 && Time.zone.now < real_now
              4.times do |week|
                create_meals_and_signups_for_week(week)
              end
            end
          end
        end
      end

      def finalize_and_run_statements
        Meals::Meal.where.not(status: "finalized").each do |meal|
          meal.status = "finalized"
          meal.build_cost(
            ingredient_cost: rand(10000) / 100.0 + 32,
            pantry_cost: rand(1000) / 100.0,
            payment_method: Meals::Cost::PAYMENT_METHODS.sample
          )
          Meals::Finalizer.new(meal).finalize!
        end
        statement_gen.generate
      end

      def create_meals_and_signups_for_week(week)
        [0, 4].each do |day|
          served_at = Time.zone.now + week.weeks + day.days + 18.hours
          datum = data.pop
          staff = adults.shuffle

          meal = build(:meal, datum.merge(
            formula: formula,
            resources: locations,
            community: community,
            head_cook: staff[0],
            asst_cooks: staff[1..2],
            cleaners: staff[3..4],
            served_at: served_at,
            creator: creator,
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
          meal.build_reservations
          meal.save!

          num_households = 5 + rand(households.size - 5)
          households.shuffle[0...num_households].each do |household|
            members = household.users.to_a
            type = bool_prob(70) ? "meat" : "veg"
            create(:meal_signup,
              meal: meal,
              household: household,
              "senior_#{type}" => members.count { |u| u.age && u.age >= 65 },
              "adult_#{type}" => members.count { |u| u.age.nil? || (u.age < 65 && u.age >= 18) },
              "big_kid_#{type}" => members.count { |u| u.age && u.age < 18 && u.age >= 5 },
              "little_kid_#{type}" => members.count { |u| u.age && u.age < 5 }
            )
            break if meal.reload.full?
          end
        end
      end
    end
  end
end

module Utils
  module FakeData
    class MealGenerator < Generator
      attr_accessor :community

      MONTHS = 5

      def initialize(community:)
        self.community = community
      end

      def generate
        create(:meals_formula, community: community)
        create_meals
      end

      private

      def create_meals
        samples = load_yaml("meals/meals.yml")
        creator = User.adults.first
        all_households = Household.all
        kitchen = Reservation::Resource.find_by(name: "Kitchen")
        dining_room = Reservation::Resource.find_by(name: "Dining Room")

        # All but 1 month of meals should be in past.
        Timecop.travel(((MONTHS - 1) * 30).days.ago.beginning_of_week.midnight) do

          # Create all meals and signups at once.
          MONTHS.times do |month|
            4.times do |week|
              [0, 4].each do |day|
                sample = samples.pop
                served_at = Time.zone.now + month.months + week.weeks + day.days + 18.hours
                staff = User.adults.active.shuffle

                meal = build(:meal, sample.merge(
                  resources: [kitchen, dining_room],
                  community: community,
                  head_cook: staff[0],
                  asst_cooks: staff[1..2],
                  cleaners: staff[3..4],
                  served_at: served_at,
                  creator: creator
                ))
                meal.build_reservations
                meal.save!

                num_households = 5 + rand(all_households.size - 5)
                all_households.shuffle[0...num_households].each do |household|
                  members = household.users.to_a
                  type = bool_prob(70) ? "meat" : "veg"
                  create(:signup,
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
    end
  end
end

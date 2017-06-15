module Utils
  # Generates fake data for a single community for demo purposes.
  class FakeDataGenerator
    include FactoryGirl::Syntax::Methods

    attr_accessor :community, :households, :users, :photos, :meal_loc

    MONTHS = 5

    def initialize(community, photos: false)
      self.community = community
      self.photos = photos
    end

    def generate
      tz = Time.zone
      Time.zone = community.settings.time_zone
      ActiveRecord::Base.transaction do
        begin
          create(:meals_formula)
          create_households_and_users
          deactivate_households
          create_resources
          create_meals

          # Creates 5 reservable resources with lorem ipsum guidelines.
          # Creates one shared guideline with heading to indicate same and attaches to a random subset of resources.
          # Creates 3 resource protocols and attaches to several resources each.
          # Creates a random assortment of reservations on the various resources.
          # Runs statements for all users.
        ensure
          users.each { |u| u.photo.destroy }
        end
      end
      Time.zone = tz
    end

    private

    # Creates 24 households (3 inactive) with random vehicles and emergency contacts.
    def create_households_and_users
      self.users = []
      adults = []
      garages = ((1..20).to_a + [nil] * 4).shuffle

      last_names = unique_set(60) { Faker::Name.last_name }

      self.households = 24.times.map do |i|
        dir = Rails.root.join("lib/random_data/households/#{i.to_s.rjust(2, "0")}/*.jpg")
        joined = Faker::Date.birthday(1, 15)
        last_name = last_names[i]

        adults = Dir[dir].map do |path|
          age = File.basename(path, ".jpg").to_i
          next if age < 16
          bday = Faker::Date.birthday(age, age + 1)
          first_name = Faker::Name.unisex_name

          build(:user,
            fake: true,
            first_name: first_name,
            last_name: bool_prob(70) ? last_name : last_names.pop,
            birthdate: bday,
            email: "#{first_name}@#{Faker::Internet.domain_name}",
            mobile_phone: Faker::PhoneNumber.simple,
            home_phone: bool_prob(50) ? Faker::PhoneNumber.simple : nil,
            work_phone: bool_prob(15) ? Faker::PhoneNumber.simple : nil,
            joined_on: joined,
            preferred_contact: %w(phone email text).sample,
            photo: photos ? File.open(path) : nil
          )
        end.compact

        kids = Dir[dir].map do |path|
          age = File.basename(path, ".jpg").to_i
          next if age >= 16
          bday = Faker::Date.birthday(age, age + 1)
          build(:user, :child,
            fake: true,
            first_name: Faker::Name.unisex_name,
            last_name: bool_prob(90) ? last_name : last_names.pop,
            email: nil,
            mobile_phone: nil,
            guardians: adults,
            birthdate: bday,
            photo: photos ? File.open(path) : nil,
            joined_on: [bday, joined].max
          )
        end.compact

        members = adults + kids
        self.users.concat(members)

        create(:household, :with_vehicles, :with_emerg_contacts,
          name: adults.map(&:last_name).uniq.join("-"),
          community: community,
          unit_num: i + 1,
          garage_nums: garages[i].to_s,
          users: members
        )
      end
    end

    # Deactivates 3 households.
    def deactivate_households
      households.shuffle[0...3].each do |h|
        joined = h.users.map(&:joined_on).max
        Timecop.travel(joined + rand((Date.today - joined).to_i)) do
          h.deactivate!
        end
      end
    end

    def create_resources
      self.meal_loc = create(:resource, meal_abbrv: "CH")
    end

    def create_meals
      samples = YAML.load_file(Rails.root.join("lib/random_data/meals.yml"))
      creator = User.adults.first
      all_households = Household.all

      # All but 1 month of meals should be in past.
      Timecop.travel(((MONTHS - 1) * 30).days.ago.beginning_of_week.midnight) do

        # Create all meals and signups at once.
        MONTHS.times do |month|
          4.times do |week|
            [0, 4].each do |day|
              sample = samples.pop
              served_at = Time.zone.now + month.months + week.weeks + day.days + 18.hours
              staff = User.adults.active.shuffle

              meal = create(:meal, sample.merge(
                resources: [meal_loc],
                community: community,
                head_cook: staff[0],
                asst_cooks: staff[1..2],
                cleaners: staff[3..4],
                served_at: served_at,
                creator: creator
              ))

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

    def distrib_rand(*pcts)
      rnd = rand(1..100)
      cum = 0
      pcts.size.times do |i|
        cum += pcts[i]
        return i if rnd <= cum
      end
      pcts.size
    end

    def bool_prob(pct)
      rand(100) < pct
    end

    def unique_set(size)
      hash = {}
      loop do
        hash[yield] = 1
        break if hash.size == size
      end
      hash.keys
    end
  end
end

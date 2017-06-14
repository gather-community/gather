module Utils
  # Generates fake data for a single community for demo purposes.
  class FakeDataGenerator
    include FactoryGirl::Syntax::Methods

    attr_accessor :community, :households, :users, :photos

    def initialize(community, photos: false)
      self.community = community
      self.photos = photos
    end

    def generate
      ActiveRecord::Base.transaction do
        create(:meals_formula)
        create_households_and_users
        deactivate_households

        # Assigns randomly chosen adults to admin, photographer, and meal biller roles.
        # Creates 10 meals with assignments, menus, signups, some of them finalized.
        # Creates 5 reservable resources with lorem ipsum guidelines.
        # Creates one shared guideline with heading to indicate same and attaches to a random subset of resources.
        # Creates 3 resource protocols and attaches to several resources each.
        # Creates a random assortment of reservations on the various resources.
        # Runs statements for all users.
      end
    end

    private

    # Creates 24 households (3 inactive) with random vehicles and emergency contacts.
    def create_households_and_users
      self.users = []
      garages = ((1..20).to_a + [nil] * 4).shuffle

      last_names = unique_set(24) { Faker::Name.last_name }

      self.households = 24.times.map do |i|
        dir = Rails.root.join("lib/random_data/households/#{i.to_s.rjust(2, "0")}/*.jpg")
        joined = Faker::Date.birthday(1, 15)
        last_name = last_names[i]

        adults = Dir[dir].map do |path|
          age = File.basename(path, ".jpg").to_i
          next if age < 16
          bday_format = "%b %d #{bool_prob(50) ? '%Y' : ''}"
          bday = Faker::Date.birthday(age, age + 1).to_time.strftime(bday_format)
          first_name = Faker::Name.unisex_name

          build(:user,
            fake: true,
            first_name: first_name,
            last_name: bool_prob(70) ? last_name : Faker::Name.last_name,
            birthdate_str: bday,
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
            last_name: last_name,
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

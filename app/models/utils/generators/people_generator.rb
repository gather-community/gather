# frozen_string_literal: true

module Utils
  module Generators
    class PeopleGenerator < Generator
      attr_accessor :community, :households, :users, :photos

      def initialize(community:, photos: false)
        self.community = community
        self.photos = photos
      end

      def generate_samples
        generate_households_and_users
        deactivate_households
        generate_memorial
      end

      private

      # Creates 24 households (3 inactive) with random vehicles and emergency contacts.
      def generate_households_and_users
        self.users = []
        adults = []
        garages = ((1..20).to_a + ([nil] * 4)).shuffle

        last_names = unique_set(60) { Faker::Name.last_name }

        self.households = 24.times.map do |i|
          household = create(:household, :with_vehicles, :with_emerg_contacts, :with_pets,
                             community: community,
                             unit_num: i + 1,
                             garage_nums: garages[i].to_s,
                             member_count: 0,
                             created_at: community.created_at,
                             updated_at: community.updated_at)

          dir = resource_path("photos/people/households/#{i.to_s.rjust(2, '0')}/*.jpg")
          joined = Faker::Date.birthday(min_age: 1, max_age: 15)
          last_name = last_names[i]

          adults = Dir[dir].map do |path|
            age = File.basename(path, ".jpg").to_i
            next if age < 16

            bday = Faker::Date.birthday(min_age: age, max_age: age + 1)
            first_name = Faker::Name.unisex_name

            email = "#{first_name}#{rand(10_000_000..99_999_999)}@example.com"

            user = build(:user,
                         :with_random_password,
                         fake: true,
                         household: household,
                         first_name: first_name,
                         last_name: bool_prob(70) ? last_name : last_names.pop,
                         birthdate: bday,
                         email: email,
                         google_email: email,
                         mobile_phone: Faker::PhoneNumber.simple,
                         home_phone: bool_prob(50) ? Faker::PhoneNumber.simple : nil,
                         work_phone: bool_prob(15) ? Faker::PhoneNumber.simple : nil,
                         joined_on: joined,
                         preferred_contact: %w[phone email text].sample,
                         created_at: community.created_at,
                         updated_at: community.updated_at)
            user.photo.attach(io: File.open(path), filename: File.basename(path)) if photos
            user
          end.compact

          adults.first.add_role(:work_coordinator) if i < 6

          kids = Dir[dir].map do |path|
            age = File.basename(path, ".jpg").to_i
            next if age >= 16

            bday = Faker::Date.birthday(min_age: age, max_age: age + 1)
            kid = build(:user, :child, :with_random_password,
                        fake: true,
                        household: household,
                        first_name: Faker::Name.unisex_name,
                        last_name: bool_prob(90) ? last_name : last_names.pop,
                        email: nil,
                        google_email: nil,
                        mobile_phone: nil,
                        guardians: adults,
                        birthdate: bday,
                        joined_on: [bday, joined].max,
                        created_at: community.created_at,
                        updated_at: community.updated_at)
            kid.photo.attach(io: File.open(path), filename: File.basename(path)) if photos
            kid
          end.compact

          users.concat(adults)
          users.concat(kids)

          household.update!(users: adults + kids, name: adults.map(&:last_name).uniq.join("-"))
          household
        end
      end

      # Deactivates 3 households.
      def deactivate_households
        households.sample(3).each do |h|
          joined = h.users.map(&:joined_on).max
          Timecop.freeze(joined + rand((Date.today - joined).to_i)) do
            h.deactivate
          end
        end
      end

      def generate_memorial
        message = "was such a kind person and a passionate member of our community. " \
                  "They will be dearly missed."
        memorial = create(:memorial, death_year: Time.current.year, user: User.adults.inactive.first)
        memorial.messages.create!(author: User.adults.sample, body: "#{memorial.user.first_name} #{message}")
      end
    end
  end
end

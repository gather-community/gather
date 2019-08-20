# frozen_string_literal: true

module Utils
  module FakeData
    class PeopleGenerator < Generator
      attr_accessor :community, :households, :users, :photos

      def initialize(community:, photos: false)
        self.community = community
        self.photos = photos
      end

      def generate_samples
        create_households_and_users
        deactivate_households
      end

      def cleanup_on_error
        users&.each { |u| u.photo&.destroy }
      end

      private

      # Creates 24 households (3 inactive) with random vehicles and emergency contacts.
      def create_households_and_users
        self.users = []
        adults = []
        garages = ((1..20).to_a + [nil] * 4).shuffle

        last_names = unique_set(60) { Faker::Name.last_name }

        self.households = 24.times.map do |i|
          household = create(:household, :with_vehicles, :with_emerg_contacts, :with_pets,
            community: community,
            unit_num: i + 1,
            garage_nums: garages[i].to_s,
            with_members: false,
            created_at: community.created_at,
            updated_at: community.updated_at)

          dir = resource_path("photos/people/households/#{i.to_s.rjust(2, '0')}/*.jpg")
          joined = Faker::Date.birthday(1, 15)
          last_name = last_names[i]

          adults = Dir[dir].map do |path|
            age = File.basename(path, ".jpg").to_i
            next if age < 16
            bday = Faker::Date.birthday(age, age + 1)
            first_name = Faker::Name.unisex_name

            email = "#{first_name}#{rand(10_000_000..99_999_999)}@example.com"

            build(:user,
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
              photo: photos ? File.open(path) : nil,
              created_at: community.created_at,
              updated_at: community.updated_at)
          end.compact

          adults.first.add_role(:work_coordinator) if i < 6

          kids = Dir[dir].map do |path|
            age = File.basename(path, ".jpg").to_i
            next if age >= 16
            bday = Faker::Date.birthday(age, age + 1)
            build(:user, :child,
              fake: true,
              household: household,
              first_name: Faker::Name.unisex_name,
              last_name: bool_prob(90) ? last_name : last_names.pop,
              email: nil,
              google_email: nil,
              mobile_phone: nil,
              guardians: adults,
              birthdate: bday,
              photo: photos ? File.open(path) : nil,
              joined_on: [bday, joined].max,
              created_at: community.created_at,
              updated_at: community.updated_at)
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
    end
  end
end

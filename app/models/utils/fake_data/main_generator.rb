module Utils
  module FakeData
    # Generates fake data for a single community for demo purposes.
    class MainGenerator < Generator
      attr_accessor :community, :households, :users, :photos

      def initialize(community:, photos: false)
        self.community = community
        self.photos = photos
      end

      def generate
        raise "Data present. Please run `rake fake:clear_data[#{community.id}]` first." if Meal.any?

        ActionMailer::Base.perform_deliveries = false

        people_gen = PeopleGenerator.new(community: community, photos: photos)
        resource_gen = ResourceGenerator.new(community: community, photos: photos)
        reservation_gen = ReservationGenerator.new(resource_map: resource_gen.resource_map)
        statement_gen = StatementGenerator.new(community: community)
        meal_gen = MealGenerator.new(community: community, statement_gen: statement_gen)

        ActiveRecord::Base.transaction do
          in_community_timezone do
            begin
              people_gen.generate
              resource_gen.generate
              reservation_gen.generate
              meal_gen.generate
            rescue
              people_gen.users.each { |u| u.photo.destroy }
              resource_gen.resources.each { |r| r.photo.destroy }
              raise $!
            end
          end
        end
      end

      private

      def in_community_timezone
        tz = Time.zone
        Time.zone = community.settings.time_zone
        yield
        Time.zone = tz
      end
    end
  end
end

module Utils
  module FakeData
    # Generates fake data for a single community for demo purposes.
    class MainGenerator < Generator
      attr_accessor :community, :households, :users, :sample_data, :photos

      def initialize(community:, sample_data: true, photos: false)
        self.community = community
        self.sample_data = sample_data
        self.photos = photos
      end

      def generate
        if Meals::Meal.any?
          raise "Data present. Please run `rake fake:clear_data[#{community.cluster_id}]` first."
        end

        ActionMailer::Base.perform_deliveries = false

        people_gen = PeopleGenerator.new(community: community, photos: photos)
        resource_gen = ResourceGenerator.new(community: community, photos: photos)
        reservation_gen = ReservationGenerator.new(community: community,
                                                   resource_map: resource_gen.resource_map)
        statement_gen = StatementGenerator.new(community: community)
        meal_gen = MealGenerator.new(community: community, statement_gen: statement_gen)

        ActiveRecord::Base.transaction do
          in_community_timezone do
            begin
              # We need to create these no matter what.
              meal_gen.generate_formula_and_roles

              # Sample data is stuff that will get deleted later.
              if sample_data
                people_gen.generate_samples
                resource_gen.generate_samples
                reservation_gen.generate_samples
                meal_gen.generate_samples
              end
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

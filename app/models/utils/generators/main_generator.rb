# frozen_string_literal: true

module Utils
  module Generators
    # Generates a single cluster and community for demo purposes.
    # Creates and sets its own tenant. Suppresses all emails.
    class MainGenerator < Generator
      include ActiveModel::Model

      attr_accessor :cmty_name, :slug, :sample_data, :photos, :cluster, :community, :generators, :country_code

      def generate
        ActionMailer::Base.perform_deliveries = false
        self.cluster = Cluster.create!(name: cmty_name)
        # ActsAsTenant has to be outside the transaction because some callbacks run after_commit.
        # So the tenant still needs to be set at that point or we get errors.
        ActsAsTenant.with_tenant(cluster) do
          ActiveRecord::Base.transaction do
            attribs = {name: cmty_name, slug: slug}
            attribs[:country_code] = country_code if country_code.present?
            self.community = Community.create!(attribs)
            in_community_timezone { generate_data_and_handle_errors }
          end
        end
        ActionMailer::Base.perform_deliveries = true
        cluster
      rescue StandardError => ex
        # Can't create the cluster inside the transaction (see above). So we need to clean up in here instead
        # in case of error.
        ActsAsTenant.with_tenant(cluster) do
          cluster.destroy
        end
        raise ex
      end

      private

      def generate_data_and_handle_errors
        build_generators

        generators.each_value(&:generate_seed_data)
        generators.each_value(&:generate_samples) if sample_data
      rescue StandardError => e
        generators.each_value(&:cleanup_on_error)
        raise e
      end

      def build_generators
        self.generators = ActiveSupport::OrderedHash.new
        generators[:people] = PeopleGenerator.new(community: community, photos: photos)
        generators[:groups] = GroupGenerator.new(community: community)
        generators[:calendars] = CalendarGenerator.new(community: community, photos: photos)
        generators[:events] = EventGenerator.new(
          community: community, calendar_map: generators[:calendars].calendar_map
        )
        generators[:statements] = StatementGenerator.new(community: community)
        generators[:meals] = MealGenerator.new(community: community, statement_gen: generators[:statements])
        generators[:restrictions] = RestrictionGenerator.new(community: community)
        generators[:work] = WorkGenerator.new(community: community)
      end
    end
  end
end

# frozen_string_literal: true

module Utils
  module Generators
    # Generates a single cluster and community for demo purposes.
    # Creates and sets its own tenant. Suppresses all emails.
    class MainGenerator < Generator
      include ActiveModel::Model

      attr_accessor :cmty_name, :slug, :sample_data, :photos, :cluster, :community, :generators

      def generate
        ActionMailer::Base.perform_deliveries = false
        self.cluster = Cluster.create!(name: cmty_name)
        # ActsAsTenant has to be outside the transaction because some callbacks run after_commit.
        # So the tenant still needs to be set at that point or we get errors.
        ActsAsTenant.with_tenant(cluster) do
          ActiveRecord::Base.transaction do
            self.community = Community.create!(name: cmty_name, slug: slug)
            in_community_timezone { generate_data_and_handle_errors }
          end
        end
        ActionMailer::Base.perform_deliveries = true
        cluster
      rescue StandardError
        # Can't create the cluster inside the transaction (see above). So we need to clean up in here instead
        # in case of error.
        cluster.destroy
      end

      private

      def generate_data_and_handle_errors
        build_generators

        # We need these even if not doing sample data.
        generators[:meals].generate_formula_and_roles
        generators[:groups].generate_everybody_group

        generators.each_value(&:generate_samples) if sample_data
      rescue StandardError => e
        generators.each_value(&:cleanup_on_error)
        raise e
      end

      def build_generators
        self.generators = ActiveSupport::OrderedHash.new
        generators[:people] = PeopleGenerator.new(community: community, photos: photos)
        generators[:groups] = GroupGenerator.new(community: community)
        generators[:resources] = ResourceGenerator.new(community: community, photos: photos)
        generators[:reservations] = ReservationGenerator.new(
          community: community, resource_map: generators[:resources].resource_map
        )
        generators[:statements] = StatementGenerator.new(community: community)
        generators[:meals] = MealGenerator.new(community: community, statement_gen: generators[:statements])
      end
    end
  end
end

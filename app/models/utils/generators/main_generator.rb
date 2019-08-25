# frozen_string_literal: true

module Utils
  module Generators
    # Generates a single cluster and community for demo purposes.
    # Creates and sets its own tenant. Suppresses all emails.
    class MainGenerator < Generator
      include ActiveModel::Model

      attr_accessor :cmty_name, :slug, :admin_attrs, :sample_data, :photos, :cluster, :community, :generators

      def generate
        ActionMailer::Base.perform_deliveries = false
        ActiveRecord::Base.transaction do
          ActsAsTenant.with_tenant(self.cluster = Cluster.create!(name: cmty_name)) do
            self.community = Community.create!(name: cmty_name, slug: slug)
            in_community_timezone { generate_data_and_handle_errors }
          end
        end
        ActionMailer::Base.perform_deliveries = true
        cluster
      end

      private

      def generate_data_and_handle_errors
        create_admin
        build_generators
        generators[:meals].generate_formula_and_roles # We need these even if not doing sample data.
        generators.each_value(&:generate_samples) if sample_data
      rescue StandardError => error
        generators.each_value(&:cleanup_on_error)
        raise error
      end

      def create_admin
        household = Household.create!(community: community, name: admin_attrs[:last_name])
        super_admin = admin_attrs.delete(:super_admin)
        admin = User.create!(admin_attrs.merge(household: household, dont_require_phone: true))
        admin.add_role(super_admin ? :super_admin : :admin)
      end

      def build_generators
        self.generators = ActiveSupport::OrderedHash.new
        generators[:people] = PeopleGenerator.new(community: community, photos: photos)
        generators[:resources] = ResourceGenerator.new(community: community, photos: photos)
        generators[:reservations] = ReservationGenerator.new(
          community: community, resource_map: generators[:resources].resource_map
        )
        generators[:statements] = StatementGenerator.new(community: community)
        generators[:meals] = MealGenerator.new(community: community, statement_gen: generators[:statements])
      end

      def in_community_timezone
        tz = Time.zone
        Time.zone = community.settings.time_zone
        yield
        Time.zone = tz
      end
    end
  end
end

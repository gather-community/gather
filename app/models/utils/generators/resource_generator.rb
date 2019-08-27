# frozen_string_literal: true

module Utils
  module Generators
    class ResourceGenerator < Generator
      attr_accessor :community, :resource_data, :resource_map, :photos

      def initialize(community:, photos:)
        self.community = community
        self.photos = photos
        self.resource_map = {}
      end

      def generate_samples
        create_resources
        create_shared_guidelines_and_associate
        create_resource_protocols_and_associate
      end

      def resources
        resource_map.values
      end

      def cleanup_on_error
        resources&.each { |u| u.photo&.destroy }
      end

      private

      def create_resources
        self.resource_data = load_yaml("reservation/resources.yml")
        resource_data.each do |row|
          resource = create(:resource, row.except("id", :shared_guideline_ids).merge(
            community: community,
            photo: photos ? resource_photo(row["id"]) : nil,
            created_at: community.created_at,
            updated_at: community.updated_at
          ))
          row[:obj] = resource
          resource_map[row["id"]] = row[:obj]
        end
      end

      def create_shared_guidelines_and_associate
        load_yaml("reservation/shared_guidelines.yml").each do |row|
          sg = Reservations::SharedGuidelines.create!(row.except("id").merge(community: community))
          resources_with_shared_guidelines_id(row["id"]).each do |resource|
            resource.shared_guidelines << sg
          end
        end
      end

      def create_resource_protocols_and_associate
        load_yaml("reservation/protocols.yml").each do |row|
          protocol = create(:reservation_protocol, row.except("id").merge(community: community))
          protocol.resources = resources_with_protocol_id(row["id"])
        end
      end

      def resource_photo(id)
        File.open(resource_path("photos/reservation/resources/#{id}.jpg"))
      end

      def resources_with_shared_guidelines_id(id)
        resource_data.select { |r| r[:shared_guideline_ids].include?(id) }.map { |r| r[:obj] }
      end

      def resources_with_protocol_id(id)
        @protocoling_data = load_yaml("reservation/protocolings.yml")
        resource_ids = @protocoling_data.select { |p| p["protocol_id"] == id }.map { |p| p["resource_id"] }
        resource_data.select { |r| resource_ids.include?(r["id"]) }.map { |r| r[:obj] }
      end
    end
  end
end

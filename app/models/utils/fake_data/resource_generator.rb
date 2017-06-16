module Utils
  module FakeData
    class ResourceGenerator < Generator
      include FactoryGirl::Syntax::Methods

      attr_accessor :community, :resource_data, :photos

      def initialize(community:, photos:)
        self.community = community
        self.photos = photos
      end

      def generate
        self.resource_data = load_yaml("reservation/resources.yml")
        create_resources
        create_shared_guidelines_and_associate
        create_resource_protocols_and_associate
      end

      private

      def create_resources
        resource_data.each do |row|
          resource = create(:resource, row.except("id", :shared_guideline_ids).merge(
            community: community,
            photo: photos ? resource_photo(row["id"]) : nil
          ))
          row[:new_id] = resource.id
        end
      end

      def create_shared_guidelines_and_associate

      end

      def create_resource_protocols_and_associate

      end

      def resource_photo(id)
        File.open(resource_path("reservation/resources/#{id}.jpg"))
      end
    end
  end
end

module Utils
  module FakeData
    class ResourceGenerator
      include FactoryGirl::Syntax::Methods

      attr_accessor :resource_data, :photos

      def initialize(photos:)
        self.photos = photos
      end

      def generate
        self.resource_data = YAML.load_file(Rails.root.join("lib/random_data/resources.yml"))
        create_resources
        create_shared_guidelines_and_associate
        create_resource_protocols_and_associate
      end

      private

      def create_resources
        resource_data.each do |row|
          resource = Reservation::Resource.create!(row.except("id", :shared_guideline_ids).merge(
            community: Community.first,
            photo: photos ? File.open(Rails.root.join("lib/random_data/resources/#{row["id"]}.jpg")) : nil
          ))
          row[:new_id] = resource.id
        end
      end

      def create_shared_guidelines_and_associate

      end

      def create_resource_protocols_and_associate

      end
    end
  end
end

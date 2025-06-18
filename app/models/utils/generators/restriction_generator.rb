module Utils
  module Generators
    class RestrictionGenerator < Generator
      attr_accessor :community

      def initialize(community:)
        self.community = community
      end

      def generate_seed_data
        r = [
          ["Gluten", "No Gluten"],
          ["Meat", "No Meat"],
          ["Tree Nuts", "No Treenuts"],
          ["Dairy", "No Dairy"],
          ["Shellfish", "No Shellfish"],
          ["Not Vegan", "Vegan"],
          ["Spicy", "Not Spicy"],
          ["Kid Friendly", "Not Kid Friendly"],
          ["Peanuts", "No Peanuts"]
        ]
        r.each do |row|
          create(:restriction, community: self.community, contains: row[0], absence: row[1])
        end

      end

    end
  end
end

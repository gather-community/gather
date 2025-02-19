module Utils
  module Generators
    class RestrictionGenerator < Generator
      attr_accessor :community

      def initialize(community:)
        self.community = community
      end

      def generate_seed_data
        r = [
          ["gluten", "no gluten"],
          ["meat", "no meat"],
          ["tree nuts", "no treenuts"],
          ["dairy", "no dairy"],
          ["shellfish", "no shellfish"],
          ["not vegan", "vegan"],
          ["spicy", "not spicy"],
          ["kid friendly", "not kid friendly"],
          ["peanuts", "no peanuts"]
        ]
        r.each do |row|
          create(:restriction, community: self.community, contains: row[0], absence: row[1])
        end

      end

    end
  end
end
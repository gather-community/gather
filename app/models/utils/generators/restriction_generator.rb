module Utils
  module Generators
    class RestrictionGenerator < Generator
      # Keys under starter_content.restrictions. Each string is looked up on its own, since a locale that
      # overrides some of them (fr-CA) would otherwise hide the rest, which it inherits.
      RESTRICTIONS = %i[gluten meat tree_nuts dairy shellfish vegan spicy kid_friendly peanuts].freeze

      attr_accessor :community

      def initialize(community:)
        self.community = community
      end

      def generate_seed_data
        RESTRICTIONS.each do |key|
          create(:restriction, community: community,
            contains: I18n.t("starter_content.restrictions.#{key}.contains"),
            absence: I18n.t("starter_content.restrictions.#{key}.absence"))
        end
      end
    end
  end
end

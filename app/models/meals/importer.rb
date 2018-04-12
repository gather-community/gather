require "csv"

module Meals
  # Imports meals
  class Importer
    attr_reader :meals

    def initialize
      # @meals = []
    end

    def import(file, community)
      CSV.foreach(file.path, headers: true) do |rows|
        pp rows.to_hash
        # meal = Meal.new_with_defaults(community)
        Meal.create!(rows.to_hash)

        # @meals.concat(meal)
        # @meals
      end
    end
  end
end

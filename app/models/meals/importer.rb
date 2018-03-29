require "csv"

module Meals
  # Imports meals
  class Importer
    attr_reader :meals

    def initialize
      @meals = []
    end

    def import(file, community)
      pp file
      pp community
      CSV.foreach(file.path) do |rows|
        pp current_community, 'importer'
        meal = Meal.new_with_defaults(community)
        meal.create!(rows.to_hash)

        @meals.concat(meal)
        @meals
      end
    end
  end
end

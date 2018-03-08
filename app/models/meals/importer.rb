require "csv"

module Meals
  # Imports meals
  class Importer
    attr_reader :meals

    def initialize
      @meals = []
    end

    def import(file)
      CSV.foreach(file.path) do |rows|
        meal = Meal.new_with_defaults(current_community)
        meal.create!(rows.to_hash)

        @meals.concat(meal)
        @meals
      end
    end
  end
end

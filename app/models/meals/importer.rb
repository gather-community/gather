require 'csv'

module Meals
  # Imports meals
  class Importer
    attr_accessor :meal

    def initialize(meal)
      @meal = meal
    end

    def import(file)
      CSV.foreach(file.path) do |rows|
        pp rows
        # Meal.create!(rows.to_hash)
      end
    end

  end
end


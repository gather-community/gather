# frozen_string_literal: true

require "csv"

module Meals
  # Imports meals from CSV.
  class CsvImporter
    attr_accessor :file, :errors

    def initialize(file)
      self.file = file
      self.errors = {}
    end

    def import
      rows = CSV.new(file).read
      if rows.empty?
        errors[0] = ["File is empty"]
        return
      end
    end
  end
end

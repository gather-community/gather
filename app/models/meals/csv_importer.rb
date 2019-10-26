# frozen_string_literal: true

require "csv"

module Meals
  # Imports meals from CSV.
  class CsvImporter
    BASIC_HEADERS = %i[served_at resource_ids formula_id community_ids].freeze

    attr_accessor :file, :errors, :community

    def initialize(file, community:)
      self.file = file
      self.errors = {}
      self.community = community
    end

    def import
      rows = CSV.new(file, converters: ->(f) { f&.strip }).read
      if rows.size < 2
        errors[0] = ["File is empty"]
        return
      else
        return unless parse_headers(rows[0])
      end
    end

    private

    def parse_headers(row)
      bad_headers = []
      row.each do |cell|
        next if header_dict[cell]
        if (match_data = cell.match(/\A#{I18n.t("csv.headers.meal.role")}(\d+)\z/))
          next if Role.in_community(community).find_by(id: match_data[1])
        end
        bad_headers << cell
      end
      return true if bad_headers.empty?
      errors[1] = ["Invalid column headers: #{bad_headers.join(', ')}"]
      false
    end

    # Returns a dictionary for looking up a header symbol based on the provided human-readable string.
    def header_dict
      @header_dict ||= BASIC_HEADERS.map { |h| [I18n.t("csv.headers.meal.#{h}"), h] }.to_h
    end
  end
end

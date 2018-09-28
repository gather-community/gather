# frozen_string_literal: true

require "csv"

module Meals
  # Imports meals
  class Importer
    include ActiveModel::Validations
    attr_reader :meals

    def initialize
      @meals = []
    end

    def succeeded?
      !@error
    end

    def import(file, community, user)
      @error = false

      # run validations
      if invalid?
        @error = true
        return succeeded?
      end

      return if @error

      CSV.foreach(file.path, headers: true, skip_lines: /^(?:,\s*)+$/) do |rows|
        formula = Meals::Formula.find_by(name: rows["formula"])

        resource_names = rows["Location(s)"].split(";").map(&:strip)
        resources = resource_names.map do |rn|
          Reservations::Resource.find_or_create_by!(name: rn, community: community)
        end

        head_cook_names = rows["Head Cook"].split
        head_cook = User.find_by(first_name: head_cook_names[0], last_name: head_cook_names[1])

        m = Meal.new_with_defaults(community)
        m.assign_attributes(
          formula: formula,
          capacity: rows["capacity"],
          served_at: rows["served_at"],
          community: community,
          creator: user
        )
        m.head_cook = head_cook
        m.resources << resources
        m.save

        @meals << m
      end

      raise ActiveRecord::Rollback if @error

      @meals
    end
  end
end

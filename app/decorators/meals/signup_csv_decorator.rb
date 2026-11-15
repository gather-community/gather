# frozen_string_literal: true

module Meals
  # Decorates Signup for CSV export. One row per household signup per meal.
  class SignupCsvDecorator < SignupDecorator
    include CsvDecorable

    SEPARATOR = "; "

    def served_at
      csv_localize(object.meal.served_at)
    end

    def meal_title
      object.meal.title
    end

    def calendars
      object.meal.calendars.map(&:name).join(SEPARATOR).presence
    end

    def formula
      object.meal.formula&.name
    end

    def community_id
      object.household.community_id
    end

    def community_name
      object.household.community.name
    end

    # Bypass the main decorator method which adds a community prefix, since we include that
    # info in separate columns.
    def household_name
      object.household.name
    end

    def diner_count(type)
      counts_by_type_id[type.id]
    end

    def takeout
      csv_bool(object.takeout?)
    end

    def created_at
      csv_localize(object.created_at)
    end

    private

    # See the note on Meals::MealCsvDecorator#signup_totals_by_type_id re: keying by ID.
    def counts_by_type_id
      @counts_by_type_id ||= object.parts.to_h { |part| [part.type_id, part.count] }
    end
  end
end

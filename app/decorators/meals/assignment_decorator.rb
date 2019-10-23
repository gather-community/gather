# frozen_string_literal: true

module Meals
  class AssignmentDecorator < ApplicationDecorator
    delegate_all

    def location_name
      meal.decorate.location_name
    end

    # starts_at may be a Date or a Time, so we have to make sure the format is defined for both.
    def starts_at_with_date
      l(starts_at, format: starts_at.is_a?(Time) ? :wday_no_year : :wday_no_year)
    end

    def date_or_times
      if date_time?
        starts_at_with_date << "–" << l(ends_at, format: :time_only)
      else
        l(starts_at.to_date, format: :wday_no_year)
      end
    end
  end
end

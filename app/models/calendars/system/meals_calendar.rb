# frozen_string_literal: true

module Calendars
  module System
    # Superclass for system-populated meals calendars
    class MealsCalendar < SystemCalendar
      MEAL_DURATION = 1.hour
    end
  end
end

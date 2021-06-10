# frozen_string_literal: true

module Calendars
  # Superclass for system-populated calendars
  class SystemCalendar < Calendar
    def system?
      true
    end
  end
end

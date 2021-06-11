# frozen_string_literal: true

module Calendars
  # Superclass for system-populated calendars
  class SystemCalendar < Calendar
    def self.model_name
      ActiveModel::Name.new(Calendar)
    end

    def system?
      true
    end
  end
end

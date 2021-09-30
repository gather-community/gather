# frozen_string_literal: true

module Calendars
  module System
    # Returns people's birthdays
    class BirthdaysCalendar < UserAnniversariesCalendar
      protected

      def attrib
        :birthdate
      end

      def emoji
        "🎂"
      end
    end
  end
end

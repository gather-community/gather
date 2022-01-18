# frozen_string_literal: true

module Calendars
  module System
    # Returns people's birthdays
    class BirthdaysCalendar < UserAnniversariesCalendar
      protected

      def slug
        :birthdays
      end

      def attrib
        :birthdate
      end

      def emoji
        "🎂"
      end
    end
  end
end

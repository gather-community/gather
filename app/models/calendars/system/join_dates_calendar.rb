# frozen_string_literal: true

module Calendars
  module System
    # Returns dates people joined the community
    class JoinDatesCalendar < UserAnniversariesCalendar
      protected

      def attrib
        :joined_on
      end

      def emoji
        "➕"
      end
    end
  end
end

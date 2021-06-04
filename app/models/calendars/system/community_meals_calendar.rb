# frozen_string_literal: true

module Calendars
  module System
    # System-populated calendar for all meals in community
    class CommunityMealsCalendar < MealsCalendar
      protected

      def hosting_communities
        [community]
      end
    end
  end
end

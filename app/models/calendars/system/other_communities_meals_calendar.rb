# frozen_string_literal: true

module Calendars
  module System
    # System-populated calendar for all meals in other communities in cluster
    class OtherCommunitiesMealsCalendar < MealsCalendar
      protected

      def hosting_communities
        Community.all - [community]
      end
    end
  end
end

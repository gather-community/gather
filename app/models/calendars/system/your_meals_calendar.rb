# frozen_string_literal: true

module Calendars
  module System
    # System-populated calendar for all meals in cluser that user has signed up for
    class YourMealsCalendar < MealsCalendar
      private

      def hosting_communities
        Community.all
      end

      def base_meals_scope(range, actor:)
        super.attended_by(actor.household)
      end

      def attended_meals(base_scope, actor:)
        base_scope
      end
    end
  end
end

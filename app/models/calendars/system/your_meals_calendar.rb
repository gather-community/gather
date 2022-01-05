# frozen_string_literal: true

module Calendars
  module System
    # System-populated calendar for all meals in cluser that user has signed up for
    class YourMealsCalendar < MealsCalendar
      protected

      def slug
        "your_meals"
      end

      private

      def hosting_communities
        Community.all
      end

      def base_meals_scope(range, actor:)
        raise ArgumentError, "actor is required for this calendar" if actor.nil?
        super.attended_by(actor.household)
      end
    end
  end
end

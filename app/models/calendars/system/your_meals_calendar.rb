# frozen_string_literal: true

module Calendars
  module System
    # System-populated calendar for all meals in cluser that user has signed up for
    class YourMealsCalendar < MealsCalendar
      protected

      def slug
        # Does not match legacy meal calendar exports
        # This may lead to some duplicates temporarily but there isn't a good alternative.
        "your_meals"
      end

      private

      def hosting_communities
        Community.all
      end

      def base_meals_scope(range, actor:)
        return Meals::Meal.none if actor.nil?

        super.attended_by(actor.household)
      end
    end
  end
end

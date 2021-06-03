# frozen_string_literal: true

module Calendars
  module System
    # System-populated calendar for all meals in community
    class CommunityMealsCalendar < MealsCalendar
      def events_between(range, user: nil)
        meals = base_meals_scope(range).order(:served_at).decorate
        attended_meals = base_meals_scope(range).attended_by(user.household).index_by(&:id) if user.present?

        meals.map do |meal|
          title = +meal.title_or_no_title
          title << " ✓" if user.present? && attended_meals.key?(meal.id)
          # We don't save the events since that's not how system calendars work.
          events.build(
            name: title,
            creator_id: meal.creator_id,
            meal_id: meal.id,
            starts_at: meal.served_at,
            ends_at: meal.served_at + MEAL_DURATION
          )
        end
      end

      private

      def base_meals_scope(range)
        Meals::Meal
          .in_community(community)
          .not_cancelled
          .where("served_at > ?", range.first - MEAL_DURATION)
          .where("served_at < ?", range.last)
      end
    end
  end
end

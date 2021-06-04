# frozen_string_literal: true

module Calendars
  module System
    # Superclass for system-populated meals calendars
    class MealsCalendar < SystemCalendar
      MEAL_DURATION = 1.hour

      def events_between(range, user:)
        scope = base_meals_scope(range, user: user)
        meals = scope.order(:served_at).decorate
        attended_meals = scope.attended_by(user.household).index_by(&:id) if user.present?

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

      def base_meals_scope(range, user:)
        Meals::MealPolicy::Scope.new(user, Meals::Meal).resolve
          .hosted_by(hosting_communities)
          .not_cancelled
          .where("served_at > ?", range.first - MEAL_DURATION)
          .where("served_at < ?", range.last)
      end
    end
  end
end

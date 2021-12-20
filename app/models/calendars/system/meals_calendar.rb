# frozen_string_literal: true

module Calendars
  module System
    # Superclass for system-populated meals calendars
    class MealsCalendar < SystemCalendar
      MEAL_DURATION = 1.hour

      def events_between(range, actor:)
        scope = base_meals_scope(range, actor: actor)
        meals = scope.order(:served_at).decorate
        attended_meals_by_id = attended_meals(scope, actor: actor).index_by(&:id) if actor.present?

        meals.map do |meal|
          title = +meal.title_or_no_title
          title << " ✓" if actor.present? && attended_meals_by_id.key?(meal.id)
          # We don't save the events since that's not how system calendars work.
          events.build(
            name: title,
            creator_id: meal.creator_id,
            meal_id: meal.id,
            starts_at: meal.served_at,
            ends_at: meal.served_at + MEAL_DURATION,
            linkable: meal,
            uid: "#{slug}_#{meal.id}"
          )
        end
      end

      def all_day_allowed?
        false
      end

      private

      def attended_meals(base_scope, actor:)
        base_scope.attended_by(actor.household)
      end

      def base_meals_scope(range, actor:)
        Meals::MealPolicy::Scope.new(actor, Meals::Meal).resolve
          .hosted_by(hosting_communities)
          .not_cancelled
          .where("served_at > ?", range.first - MEAL_DURATION)
          .where("served_at < ?", range.last)
      end
    end
  end
end

# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for meals calendars of various sorts
    class MealsExport < Export
      def kind_name
        "Meal"
      end

      protected

      def base_scope
        # Eager loading resources due to location.
        MealPolicy::Scope.new(user, Meal).resolve
          .includes(:resources)
          .with_max_age(MAX_EVENT_AGE)
          .oldest_first
      end

      def summary(meal)
        meal.title_or_no_title
      end

      def description(meal)
        cook = meal.head_cook.present? ? "By #{meal.head_cook_name}" : nil
        diner_count = if (signup = user_signups_by_meal_id[meal.id])
                        I18n.t("calendar_exports.meals.diner_count", count: signup.total)
                      end
        [cook, diner_count]
      end

      def url(meal)
        url_for(meal, :meal_url)
      end

      private

      def user_signups_by_meal_id
        @user_signups_by_meal_id ||= Signup
          .includes(:meal)
          .where(household: user.household, meal: objects)
          .index_by(&:meal_id)
      end
    end
  end
end

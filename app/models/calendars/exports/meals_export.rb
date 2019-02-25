# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for meals calendars of various sorts
    class MealsExport < Export
      def kind_name(_object)
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
        lines = []
        lines << (meal.head_cook.present? ? "By #{meal.head_cook_name}" : nil)
        signup = user_signups_by_meal_id[meal.id]
        if signup
          lines << I18n.t("calendar_exports.meals.diner_count", count: signup.total)
          if signup.comments.present?
            comments = I18n.t("calendar_exports.meals.signup_comments", comments: signup.comments)
            lines.concat(comments.split("\n"))
          end
        end
        lines
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

# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
module Calendars
  module System
    # Superclass for system-populated meals calendars
    class MealsCalendar < SystemCalendar
      MEAL_DURATION = 1.hour

      # actor may be nil in the case of a non-personalized calendar export
      def events_between(range, actor:)
        scope = base_meals_scope(range, actor: actor)
        meals = scope.order(:served_at).decorate
        signups_by_meal_id = build_signups_by_meal_id(meals: meals, actor: actor)

        meals.map do |meal|
          title = +meal.title_or_no_title
          title << " ✓" if signups_by_meal_id.key?(meal.id)
          signup = signups_by_meal_id[meal.id]

          # We don't save the events since that's not how system calendars work.
          events.build(
            name: title,
            meal_id: meal.id,
            starts_at: meal.served_at,
            ends_at: meal.served_at + MEAL_DURATION,
            location: meal.location_name,
            linkable: meal,
            uid: "#{slug}_#{meal.id}",
            note: note_for_meal(meal: meal, signup: signup)
          )
        end
      end

      def all_day_allowed?
        false
      end

      private

      def base_meals_scope(range, actor:)
        # actor may be nil in the case of a non-personalized calendar export
        # In that case we must restrict to meals that invite the current community only.
        # If actor is given, we use the MealPolicy scope which is more sensitive and can detect
        # edge-case meals that the actor may be signed up for even if their community is not invited somehow.
        base = if actor.nil?
          Meals::Meal.inviting(community)
        else
          Meals::MealPolicy::Scope.new(actor, Meals::Meal).resolve
        end
        base
          .hosted_by(hosting_communities)
          .not_cancelled
          .where("served_at > ?", range.first - MEAL_DURATION)
          .where("served_at < ?", range.last)
      end

      def note_for_meal(meal:, signup:)
        lines = []
        lines << (meal.head_cook.present? ? "By #{meal.head_cook_name}" : nil)
        if signup
          lines << I18n.t("calendar_exports.meals.diner_count", count: signup.total)
          if signup.comments.present?
            comments = I18n.t("calendar_exports.meals.signup_comments", comments: signup.comments)
            lines.concat(comments.split("\n"))
          end
        end
        lines.compact.join("\n")
      end

      def build_signups_by_meal_id(meals:, actor:)
        return {} if actor.nil?

        Meals::Signup
          .includes(:meal)
          .where(household: actor.household, meal_id: meals.map(&:id))
          .index_by(&:meal_id)
      end
    end
  end
end

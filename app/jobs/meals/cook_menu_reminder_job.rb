# frozen_string_literal: true

module Meals
  # Sends notifications reminding cook to enter menu for all applicable meals in system.
  # Sends an early one and then a later one if menu still not entered.
  class CookMenuReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        remindable_assignments(community).each do |assignment|
          MealMailer.cook_menu_reminder(assignment).deliver_now
          assignment.increment!(:cook_menu_reminder_count)
        end
      end
    end

    private

    def remindable_assignments(community)
      early = scope(community, 0, community.settings.meals.reminder_lead_times.early_menu)
      late = scope(community, 1, community.settings.meals.reminder_lead_times.late_menu)
      (early.to_a + late.to_a).uniq
    end

    def scope(community, cook_menu_reminder_count, days_from_now)
      Assignment.joins(:meal, :role)
        .where(cook_menu_reminder_count: cook_menu_reminder_count)
        .merge(Meals::Role.head_cook)
        .merge(Meal.without_menu.not_cancelled.hosted_by(community)
          .served_within_days_from_now(days_from_now))
    end
  end
end

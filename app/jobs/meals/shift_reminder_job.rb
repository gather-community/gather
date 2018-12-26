# frozen_string_literal: true

module Meals
  # Sends notifications of jobs that people have signed up for for all applicable assignments in the system.
  # Checks the DB to see when to send.
  # Runs every hour.
  class ShiftReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        Assignment::ROLES.each do |role|
          days = lead_days(community, role)
          meal_ids = Meal.hosted_by(community).served_within_days_from_now(days).not_cancelled.pluck(:id)
          assignments(meal_ids, role).each do |assignment|
            MealMailer.shift_reminder(assignment).deliver_now
            assignment.update_attribute(:reminder_count, 1)
          end
        end
      end
    end

    private

    def lead_days(community, role)
      if role.to_sym == :head_cook
        community.settings.meals.reminder_lead_times.head_cook
      else
        community.settings.meals.reminder_lead_times.job
      end
    end

    # Finds all assignments for the target meals that have not yet been notified.
    def assignments(meal_ids, role)
      return [] if meal_ids.empty?
      Assignment.where(meal_id: meal_ids).where(reminder_count: 0).where(role: role).includes(:user, :meal)
    end
  end
end

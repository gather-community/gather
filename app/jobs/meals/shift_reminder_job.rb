# Sends notifications of jobs that people have signed up for for all applicable assignments in the system.
# Checks the DB to see when to send.
# Runs every hour.
module Meals
  class ShiftReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        Assignment::ROLES.each do |role|
          lead_days = Settings.reminders.lead_times.shift[role]
          meal_ids = Meal.hosted_by(community).served_within_days_from_now(lead_days).pluck(:id)

          if meal_ids.any?
            # Find all assignments for the target meals that have not yet been notified.
            assignments = Assignment.
              where(meal_id: meal_ids).
              where(reminder_count: 0).
              where(role: role).
              includes(:user, :meal)

            # Send emails
            assignments.each do |assignment|
              MealMailer.shift_reminder(assignment).deliver_now
              assignment.update_attribute(:reminder_count, 1)
            end
          end
        end
      end
    end
  end
end

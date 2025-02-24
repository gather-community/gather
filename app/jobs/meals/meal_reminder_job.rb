# frozen_string_literal: true

module Meals
  # Sends notifications of meal signups for all applicable meals in the system.
  # Checks the DB to see when to send.
  class MealReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        lead_days = community.settings.meals.reminder_lead_times.diner
        meal_ids = Meal.hosted_by(community).served_within_days_from_now(lead_days).not_cancelled.pluck(:id)

        next unless meal_ids.any?

        # Find all households for target meals that have not yet been notified.
        signups = Signup.where(meal_id: meal_ids).where(notified: false).includes(household: :users)

        # Send emails
        signups.each do |signup|
          MealMailer.meal_reminder(signup).deliver_now
          signup.update_attribute(:notified, true)
        end
      end
    end
  end
end

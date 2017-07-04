# Sends notifications of meal signups for all applicable meals in the system.
# Checks the DB to see when to send.
module Meals
  class MealReminderJob < ReminderJob
    def perform
      lead_days = Settings.reminders.lead_times.meal

      each_community_at_correct_hour do |community|
        meal_ids = Meal.hosted_by(community).served_within_days_from_now(lead_days).pluck(:id)

        if meal_ids.any?
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
end

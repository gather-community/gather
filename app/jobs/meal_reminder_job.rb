# Sends notifications of meals that people have signed up for.
# Checks the DB to see when to send.
class MealReminderJob < ReminderJob
  def perform
    return unless correct_hour?

    lead_days = Settings.reminder_lead_times.meal
    raise "No lead time found in settings for meal notification" if lead_days.blank?

    meal_ids = Meal.served_within_days_from_now(lead_days).pluck(:id)

    if meal_ids.any?
      # Find all households for target meals that have not yet been notified.
      signups = Signup.where(meal_id: meal_ids).where(notified: false).includes(household: :users)

      # Send emails
      signups.each do |signup|
        signup.household_users.each do |user|
          NotificationMailer.meal_reminder(user, signup).deliver_now
        end
        signup.update_attribute(:notified, true)
      end
    end
  end
end

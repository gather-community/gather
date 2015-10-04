# Sends notifications of meals that people have signed up for.
# Checks the DB to see when to send.
class MealReminderJob
  MEAL_REMINDER_TIME = 18.hours

  def perform
    # Get all meals in next N hours.
    meal_ids = Meal.where("served_at > ?", Time.now).
      where("served_at < ?", Time.now + MEAL_REMINDER_TIME).pluck(:id)

    if meal_ids.any?
      # Find all households for meals in the next N hours that have not yet been notified.
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

  def max_attempts
    3
  end

  def error(job, exception)
    ExceptionNotifier.notify_exception(exception)
  end
end

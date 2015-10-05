# Sends notifications of work shifts that people have signed up for.
# Checks the DB to see when to send.
class ShiftReminderJob
  def perform
    meal_ids = Meal.ids_in_time_from_now(Settings.shift_reminder_lead_time.hours)

    if meal_ids.any?
      # Find all assignments for meals in the next N hours that have not yet been notified.
      assignments = Assignment.where(meal_id: meal_ids).where(notified: false).includes(:user, :meal)

      # Send emails
      assignments.each do |assignment|
        NotificationMailer.shift_reminder(assignment).deliver_now
        assignment.update_attribute(:notified, true)
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

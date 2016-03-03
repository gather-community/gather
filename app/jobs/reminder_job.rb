class ReminderJob

  protected

  def correct_hour?
    Time.zone.now.hour == Settings.reminder_time_of_day
  end

  def max_attempts
    1
  end

  def error(job, exception)
    ExceptionNotifier.notify_exception(exception)
  end
end


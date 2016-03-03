class ReminderJob

  protected

  def correct_hour?
    Time.zone.now.hour == Settings.reminder_time_of_day
  end
end


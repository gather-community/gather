# Sends notifications of outstanding statements a few days before they are due.
class StatementReminderJob
  def perform
    return unless correct_hour?

    remindable_statements.each do |statement|
      AccountMailer.statement_reminder(statement).deliver_now
      statement.update_attribute(:reminder_sent, true)
    end
  end

  private

  def remindable_statements
    return @remindable_statements if @remindable_statements

    lead_days = Settings.reminder_lead_times.statement
    raise "No lead time found in settings for statement notification" if lead_days.blank?

    @remindable_statements = Statement.due_within_days_from_now(lead_days).
      reminder_not_sent.with_balance_owing.is_latest
  end

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

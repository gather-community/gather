# Sends notifications of outstanding statements a few days before they are due.
class StatementReminderJob
  def perform
    remindable_statements.each do |statement|
      AccountMailer.statement_reminder(statement).deliver_now
      statement.update_attribute(:reminder_sent, true)
    end
  end

  def remindable_statements
    @remindable_statements ||= Statement.
      due_within_t_from_now(Settings.statement_reminder_lead_time.days).
      reminder_not_sent.with_balance_owing.is_latest
  end

  def max_attempts
    1
  end

  def error(job, exception)
    ExceptionNotifier.notify_exception(exception)
  end
end

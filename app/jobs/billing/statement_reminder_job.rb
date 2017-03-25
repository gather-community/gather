# Sends notifications of outstanding statements a few days before they are due.
module Billing
  class StatementReminderJob < ReminderJob
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

      lead_days = Settings.reminders.lead_times.statement
      raise "No lead time found in settings for statement notification" if lead_days.blank?

      @remindable_statements = Statement.due_within_days_from_now(lead_days).
        reminder_not_sent.with_balance_owing.is_latest
    end
  end
end

# Sends notifications of outstanding statements a few days before they are due.
module Billing
  class StatementReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        remindable_statements(community).each do |statement|
          AccountMailer.statement_reminder(statement).deliver_now
          statement.update_attribute(:reminder_sent, true)
        end
      end
    end

    private

    def remindable_statements(community)
      lead_days = Settings.reminders.lead_times.statement
      Statement.
        for_community(community).
        due_within_days_from_now(lead_days).
        reminder_not_sent.
        with_balance_owing.
        is_latest
    end
  end
end

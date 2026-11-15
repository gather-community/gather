# frozen_string_literal: true

module Billing
  # Sends notifications of outstanding statements a few days before they are due for all applicable
  # statements in system.
  class StatementReminderJob < ReminderJob
    def perform
      each_community_at_correct_hour do |community|
        remindable_statements(community).each do |statement|
          data = {statement_id: statement.id}
          each_notification_recipient(statement.household, kind: :statement_reminder, data: data) do |user|
            AccountMailer.with(recipient: user).statement_reminder(statement).deliver_now
          end
          statement.update!(reminder_sent: true)
        end
      end
    end

    private

    def remindable_statements(community)
      lead_days = community.settings.billing.statement_reminder_lead_time
      Statement
        .in_community(community)
        .due_within_days_from_now(lead_days)
        .reminder_not_sent
        .with_balance_owing
        .is_latest
    end
  end
end

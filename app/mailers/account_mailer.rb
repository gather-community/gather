# frozen_string_literal: true

# Sends emails related to billing/accounts.
class AccountMailer < ApplicationMailer
  # Billing::StatementJob sends each household member their own message with `.with(recipient:)`.
  # Without one, the whole household gets one message in the default locale.
  def statement_notice(statement)
    load_statement_vars(statement)
    mail(to: params&.dig(:recipient) || @household, reply_to: biller_emails,
      subject: default_i18n_subject(community: community.name))
  end

  # Configurable, so it goes to one recipient. See Billing::StatementReminderJob.
  def statement_reminder(statement)
    load_statement_vars(statement)
    mail(to: recipient, reply_to: biller_emails, subject: default_i18n_subject(community: community.name))
  end

  private

  def biller_emails
    User.with_biller_role.active.in_community(@statement.community).pluck(:email).compact
  end

  def load_statement_vars(statement)
    @statement = statement
    @household = statement.household.decorate
    @community = statement.community
  end
end

# frozen_string_literal: true

# Sends emails related to billing/accounts.
class AccountMailer < ApplicationMailer
  attr_reader :community

  def statement_notice(statement)
    load_statement_vars(statement)
    statement_mail(subject: "New Account Statement for #{community.name}")
  end

  def statement_reminder(statement)
    load_statement_vars(statement)
    statement_mail(subject: "Payment Reminder for #{community.name} Account")
  end

  private

  def statement_mail(params)
    mail(params.merge(to: @household, reply_to: biller_emails, include_inactive: :if_no_active))
  end

  def biller_emails
    User.with_biller_role.active.in_community(@statement.community).pluck(:email).compact
  end

  def load_statement_vars(statement)
    @statement = statement
    @household = statement.household.decorate
    @community = statement.community
  end
end

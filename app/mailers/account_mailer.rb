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
    mail(params.merge(to: @household, reply_to: biller_emails))
  end

  def biller_emails
    User.with_biller_role.in_community(@statement.community).pluck(:email).compact
  end

  def load_statement_vars(statement)
    @statement = statement
    @household = statement.household.decorate
    @community = statement.community
  end
end

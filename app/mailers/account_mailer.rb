class AccountMailer < ApplicationMailer
  attr_reader :community

  def statement_notice(statement)
    load_statement_vars(statement)
    mail(to: @household, subject: "New Account Statement for #{community.name}")
  end

  def statement_reminder(statement)
    load_statement_vars(statement)
    mail(to: @household, subject: "Payment Reminder for #{community.name} Account")
  end

  private

  def load_statement_vars(statement)
    @statement = statement
    @household = statement.household.decorate
    @community = statement.community
  end
end

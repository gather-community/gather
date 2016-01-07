class AccountMailer < ActionMailer::Base

  default from: Rails.configuration.x.from_email

  def statement_notice(statement)
    load_statement_vars(statement)
    mail(to: @household.users.map(&:email), subject: "New Account Statement for #{@community.name}")
  end

  def statement_reminder(statement)
    load_statement_vars(statement)
    mail(to: @household.users.map(&:email), subject: "Payment Reminder for #{@community.name} Account")
  end

  private

  def load_statement_vars(statement)
    @statement = statement
    @household = statement.household
    @community = statement.community
  end
end

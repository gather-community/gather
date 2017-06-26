class AccountMailer < ApplicationMailer
  def statement_notice(statement)
    load_statement_vars(statement)
    mail(to: household_emails, subject: "New Account Statement for #{@community.name}")
  end

  def statement_reminder(statement)
    load_statement_vars(statement)
    mail(to: household_emails, subject: "Payment Reminder for #{@community.name} Account")
  end

  private

  def mail(*args)
    with_community_subdomain(@community) do
      super
    end
  end

  def load_statement_vars(statement)
    @statement = statement
    @household = statement.household
    @community = statement.community
  end
end

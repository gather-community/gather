class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  default from: Settings.email.from

  def household_emails
    @household.adults.map(&:email)
  end
end

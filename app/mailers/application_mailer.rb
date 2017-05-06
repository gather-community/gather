class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  default from: Settings.email.from
end

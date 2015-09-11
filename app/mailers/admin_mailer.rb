class AdminMailer < ActionMailer::Base

  default from: Rails.configuration.x.from_email

  # Mails an error report to the webmaster.
  def error(info)
    @info = info
    path = (info[:env] && info[:env]['REQUEST_URI']) ? (": " + info[:env]['REQUEST_URI']) : ""
    exception_name = info[:exception] ? ": #{info[:exception].class} #{info[:exception].message}" : ""
    subject_extra = " #{info[:when]}"
    mail(to: Rails.configuration.x.webmaster_emails, subject: "Error#{subject_extra}#{path}#{exception_name}")
  end
end

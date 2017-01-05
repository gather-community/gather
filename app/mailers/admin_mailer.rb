class AdminMailer < ActionMailer::Base

  default from: Settings.email.from

  # Mails an error report to the webmaster.
  def error(info)
    @info = info
    path = (info[:env] && info[:env]['REQUEST_URI']) ? (": " + info[:env]['REQUEST_URI']) : ""
    exception_name = info[:exception] ? ": #{info[:exception].class} #{info[:exception].message}" : ""
    subject_extra = " #{info[:when]}"
    mail(to: Settings.email.webmaster, subject: "Error#{subject_extra}#{path}#{exception_name}")
  end
end

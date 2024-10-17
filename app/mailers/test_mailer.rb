# frozen_string_literal: true

# Sends test emails that are then checked for by the system.
class TestMailer < ActionMailer::Base
  default from: Settings.email.from, reply_to: Settings.email.no_reply

  SUBJECT = "Gather Mail Reliability Test"

  def test_mail(counter:)
    @counter = counter
    mail(to: Settings.mail_test.destination, subject: "#{SUBJECT} ##{counter}")
  end
end

# frozen_string_literal: true

require "net/pop"

class MailTestJob < ApplicationJob
  def perform
    run = MailTestRun.first || MailTestRun.new(mail_sent_at: nil)
    check_mail(run)
    send_mail(run)
    run.save!
  end

  private

  def check_mail(run)
    Rails.logger.info("Checking mail at #{Settings.mail_test.pop.host}")
    pop = Net::POP3.new(Settings.mail_test.pop.host, Settings.mail_test.pop.port)
    pop.enable_ssl if Settings.mail_test.pop.enable_ssl
    pop.start(Settings.mail_test.pop.username, Settings.mail_test.pop.password)
    pop.mails.each do |popmail|
      mail = Mail.read_from_string(popmail.pop)
      Rails.logger.info("Processing mail: #{mail.subject}")
      next unless mail.subject.include?(TestMailer::SUBJECT)

      # mail.date is a DateTime object in UTC
      sent_at = mail.date.to_time
      Rails.logger.info("Test mail found with date #{sent_at.to_fs}, recording")
      run.mail_sent_at = sent_at
    end
    pop.delete_all
    pop.finish
  end

  def send_mail(run)
    run.counter += 1
    Rails.logger.info("Sending test email ##{run.counter}")
    TestMailer.test_mail(counter: run.counter).deliver_now
  end
end

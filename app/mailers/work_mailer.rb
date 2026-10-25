# frozen_string_literal: true

# Sends work-related emails.
class WorkMailer < ApplicationMailer
  def job_reminder(assignment, reminder)
    @assignment = assignment
    @reminder = reminder
    @shift = assignment.shift.decorate
    @user = assignment.user.decorate
    @community = @shift.community

    # We don't display the time in the subject if there is a note.
    subject = if @reminder.note?
      t("work_mailer.job_reminder.subject_with_note", title: @shift.job_title, note: @reminder.note)
    else
      default_i18n_subject(title: @shift.job_title, times: @shift.times)
    end

    mail(to: recipient, subject: subject)
  end

  def job_choosing_notice(share)
    @user = share.user.decorate
    @period = share.period
    @community = @period.community
    raise "quota required" if @period.quota_none?
    @synopsis = Work::SynopsisDecorator.new(Work::Synopsis.new(period: @period, user: @user))
    mail(to: recipient)
  end
end

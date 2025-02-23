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
    times_str = @reminder.note? ? "" : ", #{@shift.times}"
    note_str = @reminder.note? ? ": #{@reminder.note}" : ""
    subject = default_i18n_subject(title: @shift.job_title, times: times_str, note: note_str)

    mail(to: @user, subject: subject)
  end

  def job_choosing_notice(share)
    @user = share.user.decorate
    @period = share.period
    @community = @period.community
    raise "quota required" if @period.quota_none?

    @synopsis = Work::SynopsisDecorator.new(Work::Synopsis.new(period: @period, user: @user))
    mail(to: @user)
  end
end

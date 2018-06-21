# frozen_string_literal: true

# Sends work-related emails.
class WorkMailer < ApplicationMailer
  def shift_reminder(assignment, reminder)
    @assignment = assignment
    @reminder = reminder
    @shift = assignment.shift.decorate
    @user = assignment.user.decorate

    # We don't display the time in the subject if there is a note.
    times_str = @reminder.note? ? "" : ", #{@shift.times}"
    note_str = @reminder.note? ? ": #{@reminder.note}" : ""
    subject = default_i18n_subject(title: @shift.job_title, times: times_str, note: note_str)

    mail(to: @user, subject: subject)
  end

  protected

  def community
    @shift.community
  end
end

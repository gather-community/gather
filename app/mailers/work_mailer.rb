# frozen_string_literal: true

# Sends work-related emails.
class WorkMailer < ApplicationMailer
  def shift_reminder(assignment)
    @assignment = assignment
    @shift = assignment.shift.decorate
    @user = assignment.user.decorate

    mail(to: @user, subject: default_i18n_subject(title: @shift.job_title, times: @shift.times))
  end

  protected
  
  def community
    @shift.community
  end
end

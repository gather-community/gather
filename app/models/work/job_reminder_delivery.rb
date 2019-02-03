# frozen_string_literal: true

module Work
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class JobReminderDelivery < ReminderDelivery
    # See parent class for associations.

    protected

    def event
      shift
    end

    def send_mail(assignment)
      WorkMailer.job_reminder(assignment, reminder).deliver_now
    end
  end
end

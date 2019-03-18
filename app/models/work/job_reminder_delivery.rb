# frozen_string_literal: true

module Work
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class JobReminderDelivery < ReminderDelivery
    # See parent class for associations.

    delegate :assignments, to: :shift

    def event
      shift
    end

    protected

    def send_mail(assignment)
      WorkMailer.job_reminder(assignment, reminder).deliver_now
    end
  end
end

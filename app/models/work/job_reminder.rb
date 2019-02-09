# frozen_string_literal: true

module Work
  # Models a reminder to do a job, or part of a job.
  class JobReminder < Reminder
    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders

    protected

    def event_key
      :shift
    end

    def remindable_events
      job.shifts
    end

    def delivery_type
      "Work::JobReminderDelivery"
    end
  end
end

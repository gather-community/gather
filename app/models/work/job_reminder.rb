# frozen_string_literal: true

module Work
  # Models a reminder to do a job, or part of a job.
  class JobReminder < Reminder
    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders

    protected

    def delivery_maintainer
      JobReminderDeliveryMaintainer.instance
    end
  end
end

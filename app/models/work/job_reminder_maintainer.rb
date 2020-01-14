# frozen_string_literal: true

module Work
  # Updates JobReminderDeliverys for various events
  class JobReminderMaintainer < ReminderMaintainer
    alias work_job_reminder_committed reminder_committed

    # You currently can't change a shift without also saving its job so we only need to handle job saves.
    def work_job_committed(job)
      shifts = job.shifts
      reminders = job.reminders
      # Run callbacks on existing deliveries to ensure recomputation.
      JobReminderDelivery.where(reminder_id: reminders.pluck(:id))
        .includes(:reminder, shift: :job).find_each(&:calculate_and_save)

      # Create any missing deliveries.
      reminders.each do |reminder|
        shifts.each do |shift|
          JobReminderDelivery.find_or_initialize_by(shift: shift, reminder: reminder).calculate_and_save
        end
      end
    end

    protected

    def event_key
      :shift
    end

    def remindable_events(reminder)
      reminder.job.shifts
    end

    def delivery_type
      "Work::JobReminderDelivery"
    end

    def eager_loads
      {shift: :job}
    end
  end
end

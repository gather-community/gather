# frozen_string_literal: true

module Work
  # Updates JobReminderDeliverys for various events
  class JobReminderDeliveryMaintainer < ReminderDeliveryMaintainer
    def job_saved(reminders)
      JobReminderDelivery.where(reminder_id: reminders.pluck(:id))
        .includes(:reminder, shift: :job).find_each(&:calculate_and_save)
    end

    def shift_saved(reminders, deliveries)
      # Run callbacks on existing deliveries to ensure recomputation.
      deliveries.includes(:reminder).find_each(&:calculate_and_save)

      # Create any missing deliveries.
      reminders.each do |reminder|
        deliveries.find_or_initialize_by(reminder: reminder).calculate_and_save
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

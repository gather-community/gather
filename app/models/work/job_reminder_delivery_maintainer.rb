# frozen_string_literal: true

module Work
  # Updates JobReminderDeliverys for various events
  class JobReminderDeliveryMaintainer < ReminderDeliveryMaintainer
    def job_saved(reminders)
      JobReminderDelivery.where(reminder_id: reminders.pluck(:id))
        .includes(:reminder, shift: :job).find_each(&:save!)
    end

    def shift_saved(reminders, deliveries)
      # Run callbacks on existing deliveries to ensure recomputation.
      deliveries.includes(:reminder).find_each(&:save!)

      # Create any missing deliveries.
      reminders.each do |reminder|
        deliveries.find_or_create_by!(reminder: reminder)
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
  end
end

# frozen_string_literal: true

# Updates ReminderDeliverys for various events
class ReminderDeliveryMaintainer
  include Singleton

  def reminder_saved(reminder, deliveries)
    # Run callbacks on existing deliveries to ensure recomputation.
    deliveries.find_each(&:calculate_and_save)
    remindable_events(reminder).find_each do |event|
      deliveries.find_or_initialize_by(event_key => event, type: delivery_type).calculate_and_save
    end
  end
end

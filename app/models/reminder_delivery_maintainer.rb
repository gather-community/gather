# frozen_string_literal: true

# Updates ReminderDeliverys for various events
class ReminderDeliveryMaintainer
  include Singleton

  def reminder_saved(reminder, deliveries)
    # Run callbacks on existing deliveries to ensure recomputation.
    deliveries.find_each(&:save!)
    remindable_events(reminder).find_each do |event|
      deliveries.find_or_create_by!(event_key => event, type: delivery_type)
    end
  end
end

# frozen_string_literal: true

# Updates ReminderDeliverys for various events
class ReminderMaintainer
  include Singleton

  def create_or_update_reminder_successful(reminder)
    deliveries = reminder.deliveries
    # Run callbacks on existing deliveries to ensure recomputation.
    deliveries_by_event = deliveries.includes(eager_loads).group_by(&:event)
    deliveries_by_event.each { |_, ds| ds.each(&:calculate_and_save) }
    remindable_events(reminder).find_each do |event|
      next if deliveries_by_event[event]

      deliveries.build(event_key => event, type: delivery_type).calculate_and_save
    end
  end
end

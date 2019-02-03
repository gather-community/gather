# frozen_string_literal: true

module Work
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class ReminderDelivery < ::ReminderDelivery
    belongs_to :reminder, class_name: "Work::Reminder", inverse_of: :deliveries
    belongs_to :shift, class_name: "Work::Shift", inverse_of: :reminder_deliveries

    protected

    def event
      shift
    end
  end
end

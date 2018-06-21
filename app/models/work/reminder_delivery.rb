# frozen_string_literal: true

module Work
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class ReminderDelivery < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :reminder, class_name: "Work::Reminder"
    belongs_to :shift, class_name: "Work::Shift"
  end
end

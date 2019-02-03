# frozen_string_literal: true

module Meals
  # Tracks the delivery of a given role reminder for a given meal, in order to prevent duplicate deliveries.
  class RoleReminderDelivery < ReminderDelivery
    belongs_to :meal, inverse_of: :reminder_deliveries

    protected

    def event
      meal
    end
  end
end

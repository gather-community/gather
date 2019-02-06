# frozen_string_literal: true

module Meals
  # Tracks the delivery of a given role reminder for a given meal, in order to prevent duplicate deliveries.
  class RoleReminderDelivery < ReminderDelivery
    # See parent class for associations.

    protected

    delegate :role, to: :reminder

    def event
      meal
    end

    # We compute start time relative to shift start to be consistent with the work module.
    def starts_at
      super + role.shift_start.minutes
    end

    def send_mail(assignment)
      MealMailer.role_reminder(assignment, reminder).deliver_now
    end
  end
end

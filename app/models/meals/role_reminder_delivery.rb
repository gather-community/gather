# frozen_string_literal: true

module Meals
  # Tracks the delivery of a given role reminder for a given meal, in order to prevent duplicate deliveries.
  class RoleReminderDelivery < ReminderDelivery
    # See parent class for associations.

    def event
      meal
    end

    def assignments
      meal.assignments_by_role[role] || []
    end

    protected

    delegate :role, to: :reminder

    # We compute start time relative to shift_start (if given) to be consistent with the work module.
    def starts_at
      super + (role.shift_start&.minutes || 0)
    end

    def send_mail(assignment)
      MealMailer.role_reminder(assignment, reminder).deliver_now
    end
  end
end

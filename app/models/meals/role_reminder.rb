# frozen_string_literal: true

module Meals
  # Models a reminder for a meal role.
  # Doesn't support absolute times since that wouldn't make sense.
  class RoleReminder < Reminder
    # Furthest distance into the future that a "days after" reminder will be honored.
    # We have to limit this because otherwise we end up having to compute/load too many objects.
    MAX_FUTURE_DISTANCE = 30.days

    belongs_to :role, class_name: "Meals::Role", inverse_of: :reminders

    protected

    def delivery_maintainer
      RoleReminderMaintainer.instance
    end
  end
end

# frozen_string_literal: true

module Meals
  # Models a reminder for a meal role.
  # Doesn't support absolute times since that wouldn't make sense.
  class RoleReminder < Reminder
    # Furthest distance into the future that a "days after" reminder will be honored.
    # We have to limit this because otherwise we end up having to compute/load too many objects.
    MAX_FUTURE_DISTANCE = 30.days

    belongs_to :role, class_name: "Meals::Role", inverse_of: :reminders, foreign_key: :role_id

    protected

    def event_key
      :meal
    end

    def remindable_events
      Meal.where(formula_id: role.formula_ids).future_or_recent(RoleReminder::MAX_FUTURE_DISTANCE)
    end

    def delivery_type
      "Meals::RoleReminderDelivery"
    end
  end
end

# frozen_string_literal: true

module Meals
  # Models a reminder for a meal role.
  # Doesn't support absolute times since that wouldn't make sense.
  class RoleReminder < Reminder
    belongs_to :role, class_name: "Meals::Role", inverse_of: :reminders, foreign_key: :role_id

    protected

    def event_key
      :meal_id
    end

    def event_ids
      Meal.where(formula_id: role.formulas.pluck(:id)).pluck(:id)
    end

    def delivery_type
      "Meals::RoleReminderDelivery"
    end
  end
end

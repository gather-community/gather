# frozen_string_literal: true

# == Schema Information
#
# Table name: reminder_deliveries
#
#  id          :bigint           not null, primary key
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  deliver_at  :datetime         not null
#  meal_id     :bigint
#  reminder_id :integer          not null
#  shift_id    :bigint
#  type        :string           not null
#  updated_at  :datetime         not null
#
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

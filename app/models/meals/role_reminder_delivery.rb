# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: reminder_deliveries
#
#  id          :bigint           not null, primary key
#  deliver_at  :datetime         not null
#  type        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  cluster_id  :integer          not null
#  meal_id     :bigint
#  reminder_id :integer          not null
#  shift_id    :bigint
#
# Indexes
#
#  index_reminder_deliveries_on_deliver_at   (deliver_at)
#  index_reminder_deliveries_on_meal_id      (meal_id)
#  index_reminder_deliveries_on_reminder_id  (reminder_id)
#  index_reminder_deliveries_on_shift_id     (shift_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (meal_id => meals.id)
#  fk_rails_...  (reminder_id => reminders.id)
#  fk_rails_...  (shift_id => work_shifts.id)
#
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

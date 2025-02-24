# frozen_string_literal: true

module Work
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
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class JobReminderDelivery < ReminderDelivery
    # See parent class for associations.

    delegate :assignments, to: :shift

    def event
      shift
    end

    protected

    def send_mail(assignment)
      WorkMailer.job_reminder(assignment, reminder).deliver_now
    end
  end
end

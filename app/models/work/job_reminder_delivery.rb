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
module Work
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class JobReminderDelivery < ReminderDelivery
    # See parent class for associations.

    delegate :assignments, to: :shift

    def event
      shift
    end

    protected

    def notification_kind
      :job_reminder
    end

    def send_mail(assignment, user)
      WorkMailer.with(recipient: user).job_reminder(assignment, reminder).deliver_now
    end
  end
end

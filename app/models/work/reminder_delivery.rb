# frozen_string_literal: true

module Work
  # Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
  class ReminderDelivery < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :reminder, class_name: "Work::Reminder"
    belongs_to :shift, class_name: "Work::Shift"

    delegate :job, :abs_time, :rel_time, :abs_time?, :rel_days?, to: :reminder
    delegate :community, :assignments, to: :shift

    before_save :compute_deliver_at

    private

    def compute_deliver_at
      self.deliver_at =
        if abs_time?
          abs_time
        elsif rel_days?
          shift.starts_at.midnight + rel_time.days + 9.hours
        else
          shift.starts_at + rel_time.hours
        end
    end
  end
end

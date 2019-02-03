# frozen_string_literal: true

# Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
class ReminderDelivery < ApplicationRecord
  acts_as_tenant :cluster

  delegate :abs_time, :rel_magnitude, :rel_sign, :abs_time?, :rel_days?, to: :reminder
  delegate :community, :assignments, to: :event

  before_save :compute_deliver_at

  private

  def compute_deliver_at
    self.deliver_at =
      if abs_time?
        abs_time
      elsif rel_days?
        event.starts_at.midnight + rel_sign * rel_magnitude.days + 9.hours
      else
        event.starts_at + rel_sign * rel_magnitude.hours
      end
  end
end

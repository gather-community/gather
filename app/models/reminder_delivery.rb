# frozen_string_literal: true

# Tracks the delivery of a given reminder for a given Shift, in order to prevent duplicate deliveries.
class ReminderDelivery < ApplicationRecord
  acts_as_tenant :cluster

  belongs_to :reminder, class_name: "Reminder", inverse_of: :deliveries

  # These are subclass-specific but they need to be up here so we can eager load them.
  belongs_to :shift, class_name: "Work::Shift", inverse_of: :reminder_deliveries
  belongs_to :meal, inverse_of: :reminder_deliveries

  delegate :abs_time, :rel_magnitude, :rel_sign, :abs_time?, :rel_days?, to: :reminder
  delegate :community, :assignments, to: :event

  before_save :compute_deliver_at

  def deliver!
    assignments.each { |assignment| send_mail(assignment) }
    destroy
  end

  protected

  def starts_at
    event.starts_at
  end

  private

  def compute_deliver_at
    self.deliver_at =
      if abs_time?
        abs_time
      elsif rel_days?
        starts_at.midnight + rel_sign * rel_magnitude.days + Settings.reminders.time_of_day.hours
      else
        starts_at + rel_sign * rel_magnitude.hours
      end
  end
end

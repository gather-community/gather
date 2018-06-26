# frozen_string_literal: true

module Work
  # Models a reminder to do a job, or part of a job.
  class Reminder < ApplicationRecord
    ABS_REL_OPTIONS = %i[relative absolute].freeze
    TIME_UNIT_OPTIONS = %i[hours days].freeze
    BEFORE_AFTER_OPTIONS = %i[before after].freeze

    acts_as_tenant :cluster

    attr_accessor :time_magnitude, :before_after

    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders
    has_many :deliveries, class_name: "Work::ReminderDelivery", inverse_of: :reminder, dependent: :destroy

    before_validation :process_magnitude_sign
    before_validation :normalize
    after_create :create_or_update_deliveries

    normalize_attributes :note

    def note?
      note.present?
    end

    def abs_time?
      abs_time.present?
    end

    def rel_days?
      rel_time.present? && time_unit == "days"
    end

    def abs_rel
      abs_time? ? "absolute" : "relative"
    end

    def create_or_update_deliveries
      job.shifts.each do |shift|
        if (delivery = deliveries.find_by(shift: shift))
          delivery.save! # Run callbacks to ensure recomputation.
        else
          deliveries.create!(shift: shift)
        end
      end
    end

    private

    # Combines, if present, the time_magnitude and before_after ephemeral attribs into rel_time.
    def process_magnitude_sign
      self.rel_time = (before_after == "before" ? -1 : 1) * time_magnitude if time_magnitude.present?
    end

    def normalize
      self.rel_time = nil if abs_time.present? && rel_time.present?

      if rel_time.present? && time_unit != "hours"
        self.time_unit = "days"
      elsif abs_time.present?
        self.time_unit = nil
      end
    end
  end
end

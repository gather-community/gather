# frozen_string_literal: true

module Work
  # Models a reminder to do a job, or part of a job.
  class Reminder < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders

    before_validation :normalize

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

    private

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

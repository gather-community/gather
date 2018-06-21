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

    def deliver_at(relative_to:)
      abs_time? ? abs_time : relative_to + rel_time.minutes
    end

    private

    def normalize
      self.rel_time = nil if abs_time.present? && rel_time.present?
    end
  end
end

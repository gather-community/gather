# frozen_string_literal: true

module Work
  class Reminder < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders

    before_validation :normalize

    private

    def normalize
      self.rel_time = nil if abs_time.present? && rel_time.present?
    end
  end
end

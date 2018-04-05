# frozen_string_literal: true

module Work
  # Assembles statistics on a work period.
  class Report
    include Calculable

    attr_accessor :period, :user

    def initialize(period:, user:)
      self.period = period
      self.user = user
    end

    def fixed_slots
      @fixed_slots ||= fixed_slot_jobs.sum(&:total_slots)
    end
  end
end

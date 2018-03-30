# frozen_string_literal: true

module Work
  # Assembles statistics on a work period.
  class Report
    attr_accessor :period

    def initialize(period:)
      self.period = period
    end
  end
end

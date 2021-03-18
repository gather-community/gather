# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting days reservered per year.
    class MaxDaysPerYearRule < MaxTimePerYearRule
      protected

      def unit
        :days
      end

      def interval(num)
        I18n.t("calendars/protocol.durations.days", count: num, formatted: num)
      end
    end
  end
end

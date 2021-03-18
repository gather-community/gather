# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting number of total minutes booked per year.
    class MaxMinutesPerYearRule < MaxTimePerYearRule
      protected

      def unit
        :minutes
      end

      def interval(num)
        Utils::TimeUtils.humanize_interval(num * 60)
      end
    end
  end
end

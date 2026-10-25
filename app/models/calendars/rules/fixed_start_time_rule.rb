# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for setting fixed start time for all events on the calendar.
    class FixedStartTimeRule < Rule
      def check(event)
        value.strftime("%T") == event.starts_at.strftime("%T") ||
          [:starts_at, I18n.t("calendars.rules.fixed_time", time: I18n.l(value, format: :time_only))]
      end
    end
  end
end

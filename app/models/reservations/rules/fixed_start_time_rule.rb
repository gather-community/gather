# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for setting fixed start time for all events on the calendar.
    class FixedStartTimeRule < Rule
      def check(event)
        value.strftime("%T") == event.starts_at.strftime("%T") ||
          [:starts_at, "Must be #{I18n.l(value, format: :time_only)}"]
      end
    end
  end
end

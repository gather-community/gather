# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for setting fixed end time for all events on the calendar.
    class FixedEndTimeRule < Rule
      def check(event)
        value.strftime("%T") == event.ends_at.strftime("%T") ||
          [:ends_at, "Must be #{I18n.l(value, format: :time_only)}"]
      end
    end
  end
end

# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting duration of events.
    class MaxLengthMinutesRule < Rule
      def check(event)
        event.ends_at - event.starts_at <= value * 60 ||
          [:ends_at, "Can be at most #{Utils::TimeUtils.humanize_interval(value * 60)} after start time"]
      end
    end
  end
end

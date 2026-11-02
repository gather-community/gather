# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting duration of events.
    class MaxLengthMinutesRule < Rule
      def check(event)
        event.ends_at - event.starts_at <= value * 60 ||
          [:ends_at,
            I18n.t("calendars.rules.max_length", length: Utils::TimeUtils.humanize_interval(value * 60))]
      end
    end
  end
end

# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting how far out events can be made.
    class MaxLeadDaysRule < Rule
      def check(event)
        event.starts_at.to_date - Time.zone.today <= value ||
          [:starts_at, "Can be at most #{value} days in the future"]
      end
    end
  end
end

# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting how far out events can be made.
    class MaxLeadDaysRule < Rule
      def check(event)
        event.starts_at.to_date - Time.zone.today <= value ||
          [:starts_at, I18n.t("calendars.rules.max_lead_days", count: value)]
      end
    end
  end
end

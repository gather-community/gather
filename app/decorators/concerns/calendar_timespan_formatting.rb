# frozen_string_literal: true

# Formats a start/end timespan for display on calendar events and eventlets. The including decorator
# must expose all_day?, single_day?, starts_at and ends_at.
module CalendarTimespanFormatting
  def timespan
    if all_day?
      if single_day?
        I18n.l(starts_at.to_date)
      else
        I18n.l(starts_at.to_date) << " - " << I18n.l(ends_at.to_date)
      end
    else
      I18n.l(starts_at) << " - " << I18n.l(ends_at, format: single_day? ? :time_only : :default)
    end
  end
end

# frozen_string_literal: true

# Only language time formats that should not differ by locale, such as machine-readable formats
# should be in this file.
Time::DATE_FORMATS[:iso8601] = "%Y-%m-%dT%H:%M:%S"
Time::DATE_FORMATS[:iso8601_date] = "%Y-%m-%d"
Date::DATE_FORMATS[:iso8601] = "%Y-%m-%d"
Date::DATE_FORMATS[:iso8601_month_day] = "%m-%d"

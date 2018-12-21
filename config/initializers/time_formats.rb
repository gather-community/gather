# frozen_string_literal: true

# Only language time formats that should not differ by locale, such as machine-readable formats
# should be in this file.
Time::DATE_FORMATS[:iso8601_no_zone] = "%Y-%m-%dT%H:%M:%S"

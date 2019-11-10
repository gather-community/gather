# frozen_string_literal: true

# Only language time formats that should not differ by locale, such as machine-readable formats
# should be in this file.
# The naming scheme assumes a base of %Y-%m-%d for dates and %Y-%m-%dT%H:%M:%S for datetimes and
# the names indicate anything that is missing from or added to those bases.
Time::DATE_FORMATS[:default] = "%Y-%m-%dT%H:%M:%S"
Time::DATE_FORMATS[:no_sep] = "%Y%m%dT%H%M%S"
Time::DATE_FORMATS[:no_time] = "%Y-%m-%d"
Date::DATE_FORMATS[:default] = "%Y-%m-%d"
Date::DATE_FORMATS[:no_sep] = "%Y%m%d"
Date::DATE_FORMATS[:no_year] = "%m-%d"

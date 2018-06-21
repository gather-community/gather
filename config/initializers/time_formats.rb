# This method of time conversion is deprecated. I18n.l is preferred.
Time::DATE_FORMATS[:full_datetime] = "%a %b %d %Y %l:%M%P"
Time::DATE_FORMATS[:short_date] = "%a %b %d"
Time::DATE_FORMATS[:regular_time] = "%l:%M%P"

# Only language independent formats should be in here.
Time::DATE_FORMATS[:machine_datetime_no_zone] = "%Y-%m-%d %H:%M"

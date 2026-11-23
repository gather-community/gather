# frozen_string_literal: true

# Rails' friendly zone names (the ones in the time zone select) don't cover every IANA zone. Communities
# in places whose clocks have split off from their neighbours need a name of their own, or they end up
# on a zone with the wrong rules.
#
# British Columbia moved to permanent UTC-7 in 2026 (tzdata 2026b). Rails only offers
# "Pacific Time (US & Canada)", which is America/Los_Angeles and still falls back to UTC-8 in winter.
ActiveSupport::TimeZone::MAPPING["British Columbia"] = "America/Vancouver"

# The zone list and lookups are memoized from MAPPING, so drop anything built before the line above.
ActiveSupport::TimeZone.clear

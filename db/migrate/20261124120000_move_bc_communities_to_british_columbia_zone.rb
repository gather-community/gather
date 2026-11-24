# frozen_string_literal: true

# Moves the two BC communities to the "British Columbia" zone (America/Vancouver, permanent UTC-7 since
# March 2026; see config/initializers/time_zones.rb).
#
# Both were on "Pacific Time (US & Canada)" until they switched to work around BC's change: Little
# Mountain to Arizona on 2026-10-26 and Ravens Crossing to Mountain Time on 2026-11-18 (from the request
# logs). This changes the setting only, and deliberately leaves stored times alone:
#
# - Times entered under Pacific for dates before March 2026 are right in BC time (the two zones were the
#   same then); the new zone shows them correctly again.
# - Times entered under Arizona or Mountain, including ones people corrected by hand after switching,
#   are right wherever that zone agrees with BC: Arizona from March 2026 on, Mountain in winter.
#
# An earlier version of this migration (#1461, removed in #1463) converted every stored time as if it had
# been entered under the current zone, and moved thousands of correct times an hour late.
class MoveBcCommunitiesToBritishColumbiaZone < ActiveRecord::Migration[8.1]
  NEW_NAME = "British Columbia"
  COMMUNITIES = {
    "littlemountain" => "Arizona",
    "ravenscrossing" => "Mountain Time (US & Canada)"
  }.freeze

  def up
    COMMUNITIES.each { |slug, old_name| set_zone(slug, from: old_name, to: NEW_NAME) }
  end

  def down
    COMMUNITIES.each { |slug, old_name| set_zone(slug, from: NEW_NAME, to: old_name) }
  end

  private

  # Skips a community whose zone isn't the expected one, so an admin's own later change isn't overridden.
  def set_zone(slug, from:, to:)
    execute(<<~SQL.squish)
      UPDATE communities SET settings = jsonb_set(settings, '{time_zone}', to_jsonb(#{quote(to)}::text))
      WHERE slug = #{quote(slug)} AND settings->>'time_zone' = #{quote(from)}
    SQL
  end

  def quote(value)
    connection.quote(value)
  end
end

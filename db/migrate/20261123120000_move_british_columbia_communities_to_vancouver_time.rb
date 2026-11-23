# frozen_string_literal: true

# British Columbia stopped falling back to UTC-8 in November 2026; its clocks stay at UTC-7 all year.
# Canadian communities on "Pacific Time (US & Canada)" (America/Los_Angeles) are in BC, so this moves
# them to "British Columbia" (America/Vancouver, added in config/initializers/time_zones.rb).
#
# Changing the setting alone isn't enough. Times people entered for dates in Los Angeles winter time
# (a 6pm meal on 1 Dec 2026) were saved as 6pm UTC-8, so under the new zone they'd read 7pm. This keeps
# what people typed: each scheduled time is read as a Los Angeles clock time and saved as the same clock
# time in Vancouver. Outside Los Angeles winter time the two zones agree and nothing changes.
#
# Only scheduled times move. Times that record when something happened (created_at, menu_posted_at, ...)
# are real instants and are left alone. Rows are updated with plain SQL so no listeners or syncs run;
# meals, their calendar events, work shifts and reminders all move by the same rule, so they stay in step.
class MoveBritishColumbiaCommunitiesToVancouverTime < ActiveRecord::Migration[8.1]
  OLD_NAME = "Pacific Time (US & Canada)"
  NEW_NAME = "British Columbia"
  OLD_TZ = "America/Los_Angeles"
  NEW_TZ = "America/Vancouver"

  # The zones agree on every instant before this (both fell back on 2026-11-01 at 09:00 UTC at the
  # earliest), so older rows can't change. The margin keeps the boundary itself in range.
  EARLIEST_CHANGE = "2026-10-31 00:00:00"

  def up
    assert_tz_data
    convert(from_name: OLD_NAME, to_name: NEW_NAME, from_tz: OLD_TZ, to_tz: NEW_TZ)
  end

  def down
    assert_tz_data
    convert(from_name: NEW_NAME, to_name: OLD_NAME, from_tz: NEW_TZ, to_tz: OLD_TZ)
  end

  private

  # Without tzdata 2026b or later, America/Vancouver still falls back and this would shift nothing,
  # so fail loudly rather than appear to succeed.
  def assert_tz_data
    offset = TZInfo::Timezone.get(NEW_TZ).to_local(Time.utc(2026, 12, 1, 12)).utc_offset
    return if offset == -7 * 3600
    raise "America/Vancouver is UTC#{offset / 3600} on 2026-12-01; tz data predates 2026b"
  end

  def convert(from_name:, to_name:, from_tz:, to_tz:)
    community_ids = select_values(<<~SQL.squish)
      SELECT id FROM communities
      WHERE country_code = 'CA' AND settings->>'time_zone' = #{quote(from_name)}
    SQL

    unless community_ids.empty?
      ids = community_ids.join(",")
      @from_tz = TZInfo::Timezone.get(from_tz)
      @to_tz = TZInfo::Timezone.get(to_tz)

      events = "SELECT id FROM calendar_events WHERE calendar_id IN " \
        "(SELECT id FROM calendar_nodes WHERE community_id IN (#{ids}))"
      jobs = "SELECT id FROM work_jobs WHERE period_id IN " \
        "(SELECT id FROM work_periods WHERE community_id IN (#{ids}))"
      reminders = "SELECT id FROM reminders WHERE job_id IN (#{jobs}) OR role_id IN " \
        "(SELECT id FROM meal_roles WHERE community_id IN (#{ids}))"

      shift("meals", %w[served_at auto_close_time], "community_id IN (#{ids})")
      shift("calendar_events", %w[starts_at ends_at], "id IN (#{events})")
      shift("calendar_event_overrides", %w[occurrence_start starts_at ends_at], "event_id IN (#{events})")
      shift("work_periods", %w[auto_open_time], "community_id IN (#{ids})")
      shift("work_shifts", %w[starts_at ends_at], "job_id IN (#{jobs})")
      shift("reminders", %w[abs_time], "id IN (#{reminders})")
      shift("reminder_deliveries", %w[deliver_at], "reminder_id IN (#{reminders})")

      execute(<<~SQL.squish)
        UPDATE communities SET settings = jsonb_set(settings, '{time_zone}', to_jsonb(#{quote(to_name)}::text))
        WHERE id IN (#{ids})
      SQL
    end

    # Signups not yet approved become communities with the zone they chose.
    execute(<<~SQL.squish)
      UPDATE community_signups SET time_zone = #{quote(to_name)}
      WHERE country_code = 'CA' AND time_zone = #{quote(from_name)}
    SQL
  end

  def shift(table, columns, scope)
    columns.each do |column|
      rows = select_rows(<<~SQL.squish)
        SELECT id, #{column} FROM #{table}
        WHERE #{scope} AND #{column} >= '#{EARLIEST_CHANGE}'
      SQL
      rows.each do |id, value|
        old_time = Time.find_zone("UTC").parse(value.to_s)
        new_time = same_clock_time(old_time)
        next if new_time == old_time
        execute("UPDATE #{table} SET #{column} = #{quote(new_time.utc.to_fs(:db))} WHERE id = #{id.to_i}")
      end
    end
  end

  # The instant at which to_tz's clock shows what from_tz's clock showed at the given instant.
  # Going back to Los Angeles (down), some Vancouver clock times don't map one-to-one: one in the hour
  # Los Angeles repeats when it falls back takes the earlier instant, and one in the hour it skips when
  # it springs forward takes the instant an hour later, as a clock that wasn't changed would show.
  def same_clock_time(time)
    local = @from_tz.to_local(time.utc)
    clock = Time.utc(local.year, local.month, local.day, local.hour, local.min, local.sec)
    begin
      @to_tz.local_to_utc(clock) { |periods| periods.first }
    rescue TZInfo::PeriodNotFound
      @to_tz.local_to_utc(clock + 1.hour) { |periods| periods.first }
    end
  end

  def quote(value)
    connection.quote(value)
  end
end

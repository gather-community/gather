# frozen_string_literal: true

# British Columbia stopped falling back to UTC-8 in November 2026; its clocks stay at UTC-7 all year.
# Rails had no zone for BC, so BC communities picked whatever matched their clocks at the time. This
# moves them to "British Columbia" (America/Vancouver, added in config/initializers/time_zones.rb).
#
# The communities are listed by slug because their old zones are shared with places outside BC: a rule
# like "Canadian and on Mountain Time" would also catch Alberta. A community is skipped if its zone is no
# longer the one listed, so an admin who has already fixed it by hand isn't overridden.
#
# Changing the setting alone isn't enough. Gather saves times in UTC, converting what people typed with
# the zone in effect at the time. Under the new zone, a 6pm meal saved under Mountain Time for July 2027
# (00:00 UTC) would read 5pm. So this keeps what people typed: each scheduled time is read as a clock
# time in the old zone and saved as the same clock time in Vancouver. Where the two zones agree, nothing
# changes; e.g. Arizona and Vancouver have agreed since March 2026.
#
# Only scheduled times move. Times that record when something happened (created_at, menu_posted_at, ...)
# are real instants and are left alone. Rows are updated with plain SQL so no listeners or syncs run;
# meals, their calendar events, work shifts and reminders all move by the same rule, so they stay in step.
class MoveBritishColumbiaCommunitiesToVancouverTime < ActiveRecord::Migration[8.1]
  NEW_NAME = "British Columbia"
  COMMUNITIES = {
    "littlemountain" => "Arizona",
    "ravenscrossing" => "Mountain Time (US & Canada)"
  }.freeze

  def up
    assert_tz_data
    COMMUNITIES.each { |slug, old_name| convert(slug, from_name: old_name, to_name: NEW_NAME) }
  end

  def down
    assert_tz_data
    COMMUNITIES.each { |slug, old_name| convert(slug, from_name: NEW_NAME, to_name: old_name) }
  end

  private

  # Without tzdata 2026b or later, America/Vancouver still falls back and the conversion would be wrong,
  # so fail loudly rather than appear to succeed.
  def assert_tz_data
    offset = TZInfo::Timezone.get("America/Vancouver").to_local(Time.utc(2026, 12, 1, 12)).utc_offset
    return if offset == -7 * 3600
    raise "America/Vancouver is UTC#{offset / 3600} on 2026-12-01; tz data predates 2026b"
  end

  def convert(slug, from_name:, to_name:)
    id = select_value(<<~SQL.squish)
      SELECT id FROM communities WHERE slug = #{quote(slug)} AND settings->>'time_zone' = #{quote(from_name)}
    SQL
    return if id.nil?

    id = id.to_i
    @from_tz = ActiveSupport::TimeZone[from_name].tzinfo
    @to_tz = ActiveSupport::TimeZone[to_name].tzinfo

    events = "SELECT id FROM calendar_events WHERE calendar_id IN " \
      "(SELECT id FROM calendar_nodes WHERE community_id = #{id})"
    jobs = "SELECT id FROM work_jobs WHERE period_id IN " \
      "(SELECT id FROM work_periods WHERE community_id = #{id})"
    reminders = "SELECT id FROM reminders WHERE job_id IN (#{jobs}) OR role_id IN " \
      "(SELECT id FROM meal_roles WHERE community_id = #{id})"

    shift("meals", %w[served_at auto_close_time], "community_id = #{id}")
    shift("calendar_events", %w[starts_at ends_at], "id IN (#{events})")
    shift("calendar_event_overrides", %w[occurrence_start starts_at ends_at], "event_id IN (#{events})")
    shift("work_periods", %w[auto_open_time], "community_id = #{id}")
    shift("work_shifts", %w[starts_at ends_at], "job_id IN (#{jobs})")
    shift("reminders", %w[abs_time], "id IN (#{reminders})")
    shift("reminder_deliveries", %w[deliver_at], "reminder_id IN (#{reminders})")

    execute(<<~SQL.squish)
      UPDATE communities SET settings = jsonb_set(settings, '{time_zone}', to_jsonb(#{quote(to_name)}::text))
      WHERE id = #{id}
    SQL
  end

  def shift(table, columns, scope)
    columns.each do |column|
      rows = select_rows("SELECT id, #{column} FROM #{table} WHERE #{scope} AND #{column} IS NOT NULL")
      rows.each do |id, value|
        old_time = Time.find_zone("UTC").parse(value.to_s)
        new_time = same_clock_time(old_time)
        next if new_time == old_time
        execute("UPDATE #{table} SET #{column} = #{quote(new_time.utc.to_fs(:db))} WHERE id = #{id.to_i}")
      end
    end
  end

  # The instant at which to_tz's clock shows what from_tz's clock showed at the given instant.
  # Where the zones changed their clocks on different days, a clock time can fall in an hour the new zone
  # repeats (the earlier instant is taken) or skips (the instant an hour later is taken, as a clock that
  # wasn't changed would show).
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

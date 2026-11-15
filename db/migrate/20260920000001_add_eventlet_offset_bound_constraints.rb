# frozen_string_literal: true

class AddEventletOffsetBoundConstraints < ActiveRecord::Migration[8.1]
  # A per-calendar eventlet (and occurrence override) stores its time as an offset from the shared
  # event time. The grid query pre-filters on the event's own times widened by MAX_OFFSET_SECONDS,
  # so an offset beyond that bound would make the eventlet silently vanish from the calendar. Enforce
  # the invariant for every writer at the database level; EventletForm supplies the user-facing
  # message before this is ever reached.
  BOUND = 43_200 # Calendars::Eventlet::MAX_OFFSET_SECONDS (12 hours) — keep in sync if that changes.

  def change
    add_check_constraint :calendar_eventlets, "start_offset BETWEEN -#{BOUND} AND #{BOUND}",
      name: :eventlet_start_offset_within_bounds
    add_check_constraint :calendar_eventlets, "end_offset BETWEEN -#{BOUND} AND #{BOUND}",
      name: :eventlet_end_offset_within_bounds
    add_check_constraint :calendar_eventlet_overrides, "start_offset BETWEEN -#{BOUND} AND #{BOUND}",
      name: :eventlet_override_start_offset_within_bounds
    add_check_constraint :calendar_eventlet_overrides, "end_offset BETWEEN -#{BOUND} AND #{BOUND}",
      name: :eventlet_override_end_offset_within_bounds
  end
end

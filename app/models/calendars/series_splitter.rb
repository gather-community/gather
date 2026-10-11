# frozen_string_literal: true

module Calendars
  # Cuts a recurring series at one of its occurrences. Used for "This and following" on both the
  # delete path (EventletDeletionForm), which just ends the series early, and the drag path
  # (EventletForm), which ends it early and carries the rest on as a new series at the new time.
  #
  # Occurrences before the cut are never touched: they stay on the original event with their
  # overrides. Callers wrap these in a transaction.
  class SeriesSplitter
    # Copied from the original event onto the new series. Meal events never recur, so meal_id isn't.
    COPIED_ATTRIBUTES = %w[name kind note creator_id sponsor_id group_id calendar_id all_day].freeze

    attr_reader :event

    def initialize(event)
      @event = event
    end

    # Ends the series with the occurrence just before this one, and drops overrides for occurrences
    # that no longer exist. UNTIL is inclusive, so setting it to the last kept occurrence is exact.
    def truncate_before(occurrence_start)
      last_kept = event.schedule.previous_occurrence(occurrence_start)
      rule = IceCube::Rule.from_hash(event.recurrence_rule)
      rule.count(nil)
      # previous_occurrence returns an IceCube::Occurrence, which ice_cube can't serialize. to_time
      # unwraps it to a zoned time, which serializes as {time:, zone:} and round-trips through JSONB.
      rule.until(last_kept.to_time)
      event.event_overrides.where(occurrence_start: occurrence_start..).destroy_all
      event.update!(recurrence_rule: rule.to_hash)
    end

    # Ends the series before this occurrence and returns a new event carrying on from it, moved by
    # the given shifts (zero shifts for a split that only changes one calendar's offsets). A start
    # shift moves the new series; an end shift that differs from it changes its duration.
    #
    # The occurrences from the cut on keep their overrides, which move to the new event with new
    # keys. As when a whole series moves (see Event#shift_series_dependents), an occurrence someone
    # moved keeps its own time and a calendar-only change follows its occurrence. Overrides are moved
    # through the original event's association, so any a caller already has loaded are updated in
    # place rather than left pointing at the old event.
    def split_at(occurrence_start, start_shift:, end_shift:)
      continuation = build_continuation(occurrence_start, start_shift, end_shift)
      continuation.save!
      move_overrides(occurrence_start, continuation, start_shift)
      # Last, since it destroys any overrides still on the original event from the cut on.
      truncate_before(occurrence_start)
      continuation
    end

    private

    def build_continuation(occurrence_start, start_shift, end_shift)
      duration = event.ends_at - event.starts_at
      continuation = Event.new(event.attributes.slice(*COPIED_ATTRIBUTES))
      continuation.starts_at = start_shift.apply(occurrence_start)
      continuation.ends_at = end_shift.apply(occurrence_start + duration)
      continuation.recurrence_rule = continuation_rule(occurrence_start, start_shift)
      # Built before the first save: Event#sync_eventlet adds an eventlet to an event that has none,
      # so copies added after saving would collide with it on the [event_id, calendar_id] index.
      # Reloaded so a calendar added since the association was cached isn't left behind.
      event.eventlets.reload.each do |e|
        continuation.eventlets.build(calendar_id: e.calendar_id, start_offset: e.start_offset,
          end_offset: e.end_offset)
      end
      continuation
    end

    # The original rule, picking up from the cut: a COUNT becomes the occurrences that remain, and an
    # UNTIL moves with the series so it still ends on the same occurrence.
    def continuation_rule(occurrence_start, start_shift)
      rule = IceCube::Rule.from_hash(event.recurrence_rule)
      if (count = rule.to_hash[:count])
        rule.count(event.schedule.first(count).count { |t| t >= occurrence_start })
      elsif rule.until_time
        rule.until(start_shift.apply(rule.until_time))
      end
      rule.to_hash
    end

    def move_overrides(occurrence_start, continuation, start_shift)
      eventlets_by_calendar = continuation.eventlets.index_by(&:calendar_id)
      moving = event.event_overrides.select { |o| o.occurrence_start >= occurrence_start }
      moving.each do |override|
        override.update!(event: continuation, occurrence_start: start_shift.apply(override.occurrence_start))
        override.eventlet_overrides.each do |eo|
          eo.update!(eventlet: eventlets_by_calendar.fetch(eo.eventlet.calendar_id))
        end
      end
    end
  end
end

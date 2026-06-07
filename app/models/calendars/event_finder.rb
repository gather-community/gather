# frozen_string_literal: true

module Calendars
  # Finds events on a given group of calendars over a given range
  class EventFinder
    include ActiveModel::Model

    attr_accessor :range, :user, :calendars, :own_only

    def events
      # Note: the `events` path does not expand recurring occurrences; it is being superseded by
      # `eventlets`. All display and export code uses `eventlets`.
      @events ||= normal_events + system_events
    end

    def eventlets
      @eventlets ||= non_recurring_eventlets + recurring_occurrences + system_eventlets
    end

    private

    def normal_events
      scope = EventPolicy::Scope.new(user, Event).resolve
        .between(range)
        .includes(:calendar)
        .where(calendar: non_system_calendars)
        .where(recurrence_rule: nil)
      scope = scope.where(creator: user).where(group: nil) if own_only
      scope.to_a
    end

    def system_events
      # If own_only is true, we exclude all system events because all such events are created by the system.
      return [] if own_only
      system_calendars.map { |c| c.events_between(range, actor: user) }.flatten
    end

    def non_recurring_eventlets
      scope = EventletPolicy::Scope.new(user, Eventlet).resolve
        .between(range)
        .joins(:event)
        .where(calendar_events: {recurrence_rule: nil})
        .includes(:calendar, :event)
        .where(calendar: non_system_calendars)
      scope = scope.where(calendar_events: {creator: user, group: nil}) if own_only
      scope.to_a
    end

    def recurring_occurrences
      return [] if own_only
      base_eventlets = recurring_eventlet_scope.to_a
      return [] if base_eventlets.empty?
      overrides_by_eventlet = load_overrides(base_eventlets.map(&:id))
      base_eventlets.flat_map { |e| occurrences_for_eventlet(e, overrides_by_eventlet) }
    end

    def occurrences_for_eventlet(eventlet, overrides_by_eventlet)
      overrides = overrides_by_eventlet[eventlet.id] || {}
      base_start_off = eventlet.start_offset
      base_end_off = eventlet.end_offset
      from_schedule, seen = scheduled_occurrences(eventlet, overrides, base_start_off, base_end_off)
      from_schedule + moved_in_occurrences(eventlet, overrides, seen, base_start_off, base_end_off)
    end

    # Expands IceCube occurrences in range, applying deletion/move overrides.
    # Returns [eventlet_list, seen_occ_starts_hash] so the caller can detect moved-in ones.
    def scheduled_occurrences(eventlet, overrides, base_start_off, base_end_off)
      seen = {}
      results = eventlet.event.occurrences_between(range).filter_map do |occ_s, occ_e|
        seen[occ_s] = true
        override = overrides[occ_s]
        next if override&.deleted?
        actual_s = override&.starts_at || occ_s
        actual_e = override&.ends_at || occ_e
        next unless range.cover?(actual_s)
        build_occurrence_eventlet(eventlet, occ_s, actual_s, actual_e, base_start_off, base_end_off)
      end
      [results, seen]
    end

    # Returns transient eventlets for overrides that move an occurrence into the range from outside it.
    def moved_in_occurrences(eventlet, overrides, seen, base_start_off, base_end_off)
      overrides.filter_map do |occ_s, override|
        next if seen.key?(occ_s)
        next if override.deleted?
        next unless override.starts_at && range.cover?(override.starts_at)
        build_occurrence_eventlet(eventlet, occ_s, override.starts_at, override.ends_at,
          base_start_off, base_end_off)
      end
    end

    # Returns overrides keyed by eventlet_id, then by occurrence_start.
    def load_overrides(eventlet_ids)
      EventOverride
        .where(eventlet_id: eventlet_ids)
        .group_by(&:eventlet_id)
        .transform_values { |os| os.index_by(&:occurrence_start) }
    end

    def build_occurrence_eventlet(base_eventlet, original_occ_s, actual_s, actual_e,
      base_start_off, base_end_off)
      parent = base_eventlet.event
      te = build_transient_event(parent, base_eventlet.calendar, actual_s, actual_e)
      Eventlet.new(event: te, calendar: base_eventlet.calendar,
        start_offset: base_start_off, end_offset: base_end_off)
        .tap do |occ|
          # UID is based on the original occurrence time so it stays stable even when moved.
          occ.uid = "#{parent.id}_#{original_occ_s.to_i}"
          occ.occurrence_start = original_occ_s
          occ.linkable = parent
          occ.location = base_eventlet.location
        end
    end

    def build_transient_event(parent, calendar, starts_at, ends_at)
      Event.new(
        name: parent.name, kind: parent.kind, note: parent.note, all_day: parent.all_day,
        creator: parent.creator, group: parent.group, meal_id: parent.meal_id,
        calendar: calendar, starts_at: starts_at, ends_at: ends_at
      ).tap { |e| e.uid = "#{parent.id}_#{starts_at.to_i}" }
    end

    def recurring_eventlet_scope
      EventletPolicy::Scope.new(user, Eventlet).resolve
        .joins(:event)
        .where.not(calendar_events: {recurrence_rule: nil})
        .where(calendar: non_system_calendars)
        .where("calendar_events.starts_at < ?", range.last)
        .where(
          "calendar_events.recurrence_end_date IS NULL " \
          "OR calendar_events.recurrence_end_date >= ?",
          range.first.to_date
        )
        .includes(:calendar, :event)
    end

    def system_eventlets
      # own_only excludes system eventlets — all system eventlets are created by the system, not a user.
      return [] if own_only
      system_calendars.map { |c| c.eventlets_between(range, actor: user) }.flatten
    end

    def non_system_calendars
      @non_system_calendars ||= calendars - system_calendars
    end

    def system_calendars
      @system_calendars ||= calendars.select(&:system?)
    end
  end
end

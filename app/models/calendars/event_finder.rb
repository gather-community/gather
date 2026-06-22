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

      # One query for event-level overrides (with eventlet_overrides eagerly loaded).
      event_overrides_by_event = load_event_overrides(base_eventlets.map { |e| e.event.id })

      base_eventlets.flat_map do |eventlet|
        overrides = event_overrides_by_event[eventlet.event.id] || {}
        occurrences_for_eventlet(eventlet, overrides)
      end
    end

    def load_event_overrides(event_ids)
      EventOverride
        .where(event_id: event_ids)
        .includes(:eventlet_overrides)
        .group_by(&:event_id)
        .transform_values { |os| os.index_by(&:occurrence_start) }
    end

    def occurrences_for_eventlet(eventlet, event_overrides)
      from_schedule, seen = scheduled_occurrences(eventlet, event_overrides)
      from_schedule + moved_in_occurrences(eventlet, event_overrides, seen)
    end

    # Expands IceCube occurrences using a looser range (±MAX_OFFSET_SECONDS) so that EventletOverride
    # offsets can shift an occurrence into the visible window. Applies a tight range.cover? afterward.
    # Returns [eventlet_list, seen_occ_starts_hash] for the moved-in pass.
    def scheduled_occurrences(eventlet, event_overrides)
      expanded = (range.first - Eventlet::MAX_OFFSET_SECONDS)..(range.last + Eventlet::MAX_OFFSET_SECONDS)
      seen = {}
      results = eventlet.event.occurrences_between(expanded).filter_map do |occ_s, occ_e|
        seen[occ_s] = true
        event_override = event_overrides[occ_s]
        next if event_override&.deleted?
        base_s = event_override&.starts_at || occ_s
        base_e = event_override&.ends_at || occ_e
        eventlet_override = find_eventlet_override(event_override, eventlet)
        next if eventlet_override&.deleted?
        start_off, end_off = resolve_offsets(eventlet, eventlet_override)
        next unless range.cover?(base_s + start_off.seconds)
        build_occurrence_eventlet(eventlet, occ_s, base_s, base_e, start_off, end_off)
      end
      [results, seen]
    end

    # Returns transient eventlets for EventOverrides that move an occurrence into the range from outside it.
    # EventletOverride offsets are bounded by MAX_OFFSET_SECONDS, so the expanded-range trick above
    # handles those — this path is only needed for unbounded EventOverride time changes.
    def moved_in_occurrences(eventlet, event_overrides, seen)
      event_overrides.filter_map do |occ_s, event_override|
        next if seen.key?(occ_s)
        next if event_override.deleted?
        next unless event_override.starts_at && range.cover?(event_override.starts_at)
        eventlet_override = find_eventlet_override(event_override, eventlet)
        next if eventlet_override&.deleted?
        start_off, end_off = resolve_offsets(eventlet, eventlet_override)
        build_occurrence_eventlet(eventlet, occ_s, event_override.starts_at, event_override.ends_at,
          start_off, end_off)
      end
    end

    def find_eventlet_override(event_override, eventlet)
      event_override&.eventlet_overrides&.find { |eo| eo.eventlet_id == eventlet.id }
    end

    def resolve_offsets(eventlet, eventlet_override)
      [
        eventlet_override&.start_offset || eventlet.start_offset,
        eventlet_override&.end_offset || eventlet.end_offset
      ]
    end

    def build_occurrence_eventlet(base_eventlet, original_occ_s, base_s, base_e, start_off, end_off)
      Eventlet.build_occurrence(base_eventlet: base_eventlet, occurrence_start: original_occ_s,
        starts_at: base_s, ends_at: base_e, start_offset: start_off, end_offset: end_off)
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

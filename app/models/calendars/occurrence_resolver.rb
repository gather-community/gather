# frozen_string_literal: true

module Calendars
  # Resolves a single occurrence of a (possibly recurring) base eventlet for the show page.
  #
  # Given a persisted base eventlet and a raw `occurrence` param (a unix timestamp string, or nil),
  # returns the transient occurrence Eventlet to display, or nil if the occurrence is invalid or has
  # been deleted (the controller turns nil into a 404).
  #
  # The override-resolution rules mirror EventFinder's bulk expansion so the show page and the
  # calendar grid agree on which occurrences exist and at what time.
  class OccurrenceResolver
    attr_reader :base_eventlet, :occurrence_param

    def initialize(base_eventlet, occurrence_param)
      @base_eventlet = base_eventlet
      @occurrence_param = occurrence_param
    end

    def resolve
      return resolve_non_recurring unless event.recurring?

      occurrence_start = target_occurrence_start
      return nil unless event.schedule.occurs_at?(occurrence_start)

      event_override = find_event_override(occurrence_start)
      return nil if event_override&.deleted?

      eventlet_override = find_eventlet_override(event_override)
      return nil if eventlet_override&.deleted?

      build(occurrence_start, event_override, eventlet_override)
    end

    private

    def event
      base_eventlet.event
    end

    # A non-recurring event has no occurrences, so an occurrence param is nonsensical → 404.
    # Without a param we just show the eventlet itself.
    def resolve_non_recurring
      occurrence_param.present? ? nil : base_eventlet
    end

    # The occurrence the URL points at, or the series' first occurrence when no param is given.
    def target_occurrence_start
      return event.schedule.first if occurrence_param.blank?
      Time.zone.at(occurrence_param.to_i)
    end

    # Match by unix second, the same way the URL was generated, to avoid sub-second mismatches.
    def find_event_override(occurrence_start)
      event.event_overrides.includes(:eventlet_overrides)
        .detect { |o| o.occurrence_start.to_i == occurrence_start.to_i }
    end

    def find_eventlet_override(event_override)
      return nil unless event_override
      event_override.eventlet_overrides.detect { |eo| eo.eventlet_id == base_eventlet.id }
    end

    def build(occurrence_start, event_override, eventlet_override)
      duration = event.ends_at - event.starts_at
      base_s = event_override&.starts_at || occurrence_start
      base_e = event_override&.ends_at || (occurrence_start + duration)
      start_off = eventlet_override&.start_offset || base_eventlet.start_offset
      end_off = eventlet_override&.end_offset || base_eventlet.end_offset

      Eventlet.build_occurrence(base_eventlet: base_eventlet, occurrence_start: occurrence_start,
        starts_at: base_s, ends_at: base_e, start_offset: start_off, end_offset: end_off)
    end
  end
end

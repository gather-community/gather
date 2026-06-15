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
      recurring_eventlet_scope.flat_map do |eventlet|
        event = eventlet.event
        base_start_off = eventlet.start_offset
        base_end_off = eventlet.end_offset
        event.occurrences_between(range).map do |occ_s, occ_e|
          build_occurrence_eventlet(eventlet, occ_s, occ_e, base_start_off, base_end_off)
        end
      end
    end

    def build_occurrence_eventlet(base_eventlet, occ_s, occ_e, base_start_off, base_end_off)
      parent = base_eventlet.event
      te = build_transient_event(parent, base_eventlet.calendar, occ_s, occ_e)
      Eventlet.new(event: te, calendar: base_eventlet.calendar,
        start_offset: base_start_off, end_offset: base_end_off)
        .tap do |occ|
          occ.uid = te.uid
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

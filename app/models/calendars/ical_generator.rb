# frozen_string_literal: true

require "icalendar"
require "icalendar/tzinfo"

module Calendars
  # Generates ICS files for various calendars in the system from a set of Eventlet objects.
  class IcalGenerator
    include Rails.application.routes.url_helpers

    UID_SIGNATURE = "91a772a5ae4a"

    attr_accessor :calendar_name, :grouped_eventlets, :recurring_representatives, :cal, :url_options

    def initialize(calendar_name:, eventlets:, url_options:)
      self.calendar_name = calendar_name
      recurring, non_recurring = eventlets.partition { |e| !e.persisted? && e.linkable.is_a?(Eventlet) }
      self.grouped_eventlets = non_recurring.group_by do |eventlet|
        [
          eventlet.starts_at,
          eventlet.ends_at,
          eventlet.creator_id,
          eventlet.meal_id,
          eventlet.name
        ]
      end.values
      # One representative per (event series, calendar) pair — each calendar may have a different
      # display offset, producing a separate RRULE VEVENT.
      self.recurring_representatives = recurring.uniq { |e| [e.linkable.id, e.calendar_id] }
      self.url_options = url_options
      load_series_overrides
    end

    def generate
      self.cal = Icalendar::Calendar.new
      set_timezone
      grouped_eventlets.each { |group| add_event_group(group) }
      recurring_representatives.each { |occ| add_recurring_event(occ) }
      cal.append_custom_property("X-WR-CALNAME", calendar_name)
      cal.publish
      cal.to_ical
    end

    private

    def series_context_for(occurrence)
      # linkable is the persisted base eventlet; the real series event is reached via .event.
      base_eventlet = occurrence.linkable
      parent = base_eventlet.event
      event_overrides = @event_overrides_by_event[parent.id] || []
      [parent, base_eventlet, event_overrides]
    end

    def load_series_overrides
      parent_event_ids = recurring_representatives.map { |r| r.linkable.event_id }.uniq
      if parent_event_ids.empty?
        @event_overrides_by_event = {}
        return
      end

      @event_overrides_by_event = EventOverride.where(event_id: parent_event_ids)
        .includes(:eventlet_overrides)
        .group_by(&:event_id)
    end

    def add_event_group(group)
      raise ArgumentError, "all events must specify uid" if group[0].uid.nil?

      cal.event do |e|
        # UID should be unique within the calendar. It is how the importing system determines which
        # events have changed when it refreshes the calendar.
        e.uid = [UID_SIGNATURE, group[0].uid].join("_")
        e.dtstart = date_or_time_value(group[0].starts_at, all_day: group[0].all_day?)
        e.dtend = date_or_time_value(group[0].ends_at, all_day: group[0].all_day?, is_end: true)
        e.location = group.map(&:location).join(" + ")
        e.summary = group[0].name
        # Google calendar doesn't display the given ICS URL attribute it seems (as of 7/14/2018)
        # so we include it at the end of the description instead.
        e.description = (group.map(&:note) + [url_for_event(group[0])]).compact.join("\n")
      end
    end

    def add_recurring_event(occurrence)
      # linkable is the persisted parent event — use it for RRULE and URL.
      # Apply the eventlet's offset to DTSTART/DTEND so each calendar's display time is correct.
      parent, base_eventlet, event_overrides = series_context_for(occurrence)

      cal.event do |e|
        e.uid = [UID_SIGNATURE, parent.id, occurrence.calendar_id].join("_")
        e.dtstart = date_or_time_value(parent.starts_at + occurrence.start_offset.seconds,
          all_day: occurrence.all_day?)
        e.dtend = date_or_time_value(parent.ends_at + occurrence.end_offset.seconds,
          all_day: occurrence.all_day?, is_end: true)
        e.rrule = Icalendar::Values::Recur.new(parent.schedule.rrules.first.to_ical)
        e.location = occurrence.location
        e.summary = occurrence.name
        e.description = ([occurrence.note] + [url_for_event(occurrence)]).compact.join("\n")
        apply_exdates(e, event_overrides, base_eventlet, occurrence)
      end

      emit_recurrence_id_vevents(event_overrides, base_eventlet, occurrence)
    end

    # Emits EXDATE lines for occurrences that are suppressed on this calendar.
    # An EXDATE is needed when the occurrence is deleted/moved at the event level, or when there is
    # an eventlet-level override for this calendar's eventlet (deleted or offset-shifted).
    # Overrides that only affect a different calendar's eventlet must not produce an EXDATE here,
    # or the occurrence would vanish from this calendar with no replacement VEVENT.
    def apply_exdates(ical_event, event_overrides, base_eventlet, occurrence)
      exdates = event_overrides.filter_map do |eo|
        elo = find_eventlet_override(eo, base_eventlet)
        next unless eo.deleted? || eo.starts_at || elo
        # iCal occurrence time for this calendar = original occurrence + base eventlet offset.
        eo.occurrence_start + (base_eventlet&.start_offset || 0).seconds
      end
      return unless exdates.any?
      ical_event.exdate = exdates.map { |t| date_or_time_value(t, all_day: occurrence.all_day?) }
    end

    # Emits a replacement VEVENT (with RECURRENCE-ID) for each override that moves rather than
    # deletes an occurrence. Handles the five combinations documented in the class header.
    def emit_recurrence_id_vevents(event_overrides, base_eventlet, occurrence)
      event_overrides.each do |event_override|
        elo = find_eventlet_override(event_override, base_eventlet)
        next if event_override.deleted? || elo&.deleted?
        next unless event_override.starts_at || elo
        recurrence_id_time = event_override.occurrence_start +
          (base_eventlet&.start_offset || 0).seconds
        new_start, new_end = resolve_override_times(event_override, elo, base_eventlet, occurrence)
        add_override_vevent(occurrence, recurrence_id_time, new_start, new_end)
      end
    end

    def add_override_vevent(occurrence, recurrence_id_time, new_start, new_end)
      cal.event do |e|
        e.uid = [UID_SIGNATURE, occurrence.linkable.event_id, occurrence.calendar_id].join("_")
        e.recurrence_id = date_or_time_value(recurrence_id_time, all_day: occurrence.all_day?)
        e.dtstart = date_or_time_value(new_start, all_day: occurrence.all_day?)
        e.dtend = date_or_time_value(new_end, all_day: occurrence.all_day?, is_end: true)
        e.location = occurrence.location
        e.summary = occurrence.name
        e.description = ([occurrence.note] + [url_for_event(occurrence)]).compact.join("\n")
      end
    end

    # Computes the new DTSTART/DTEND for a RECURRENCE-ID VEVENT, combining any EventOverride
    # time change with any EventletOverride offset change.
    def resolve_override_times(event_override, eventlet_override, base_eventlet, occurrence)
      parent = base_eventlet.event
      duration = parent.ends_at - parent.starts_at

      # EventOverride provides new absolute event times; fall back to the occurrence's original time.
      base_s = event_override.starts_at || event_override.occurrence_start
      base_e = event_override.ends_at || (event_override.occurrence_start + duration)

      # EventletOverride provides a per-occurrence offset; fall back to the base eventlet's offset.
      start_off = eventlet_override&.start_offset || base_eventlet&.start_offset || 0
      end_off = eventlet_override&.end_offset || base_eventlet&.end_offset || 0

      [base_s + start_off.seconds, base_e + end_off.seconds]
    end

    def find_eventlet_override(event_override, base_eventlet)
      return nil unless base_eventlet
      event_override.eventlet_overrides.find { |elo| elo.eventlet_id == base_eventlet.id }
    end

    def url_for_event(eventlet)
      linkable = eventlet.linkable
      if linkable.is_a?(Work::Shift)
        # Work shift show pages are period-scoped, so they can't be reached polymorphically.
        work_period_shift_url(linkable.period, linkable, **url_options)
      elsif linkable.present?
        # Recurring occurrence → base eventlet → eventlet show page; system calendars → meal/job/user.
        polymorphic_url(linkable, **url_options)
      elsif eventlet.persisted?
        calendars_eventlet_url(eventlet, **url_options)
      else
        raise ArgumentError, "unpersisted events must define linkable"
      end
    end

    def date_or_time_value(time, all_day:, is_end: false)
      if all_day
        date = time.to_date
        date += 1.day if is_end
        Icalendar::Values::Date.new(date)
      else
        Icalendar::Values::DateTime.new(time, tzid: tzid)
      end
    end

    # Sets up the calendar's timzeone blocks at the top of the file.
    # This is kind of a weird incantation taken from the gem docs.
    # Version 2 of the gem is supposed to have better timezone support, if it ever comes out.
    # This method may fail with TZInfo::AmbiguousTime during DST transitions. The problem should
    # go away after a few hours though.
    def set_timezone
      tz = TZInfo::Timezone.get(tzid)
      cal.add_timezone(tz.ical_timezone(Time.current))
    end

    # Current timezone ID in tzinfo format.
    def tzid
      Time.zone.tzinfo.name
    end
  end
end

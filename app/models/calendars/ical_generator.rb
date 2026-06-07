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
      recurring, non_recurring = eventlets.partition { |e| !e.persisted? && e.linkable.is_a?(Event) }
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

    def load_series_overrides
      parent_event_ids = recurring_representatives.map { |r| r.linkable.id }.uniq
      if parent_event_ids.empty?
        @series_overrides = {}
        return
      end

      base_eventlets = Eventlet.where(event_id: parent_event_ids)
        .index_by { |e| [e.event_id, e.calendar_id] }
      overrides_by_eventlet = EventOverride.where(eventlet_id: base_eventlets.values.map(&:id))
        .group_by(&:eventlet_id)

      @series_overrides = base_eventlets.transform_values do |eventlet|
        overrides_by_eventlet[eventlet.id] || []
      end
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
      parent = occurrence.linkable
      deleted_overrides, moved_overrides = series_overrides_for(occurrence).partition(&:deleted?)

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
        apply_exdates(e, deleted_overrides + moved_overrides, occurrence)
      end

      moved_overrides.each { |override| add_override_event(occurrence, override) }
    end

    def series_overrides_for(occurrence)
      @series_overrides[[occurrence.linkable.id, occurrence.calendar_id]] || []
    end

    def apply_exdates(ical_event, overrides, occurrence)
      exdates = overrides.map(&:occurrence_start)
      return unless exdates.any?
      ical_event.exdate = exdates.map { |t| date_or_time_value(t, all_day: occurrence.all_day?) }
    end

    def add_override_event(series_occurrence, override)
      parent = series_occurrence.linkable
      cal.event do |e|
        e.uid = [UID_SIGNATURE, parent.id, series_occurrence.calendar_id].join("_")
        e.recurrence_id = date_or_time_value(override.occurrence_start, all_day: series_occurrence.all_day?)
        e.dtstart = date_or_time_value(override.starts_at, all_day: series_occurrence.all_day?)
        e.dtend = date_or_time_value(override.ends_at, all_day: series_occurrence.all_day?, is_end: true)
        e.location = series_occurrence.location
        e.summary = series_occurrence.name
        e.description = ([series_occurrence.note] + [url_for_event(series_occurrence)]).compact.join("\n")
      end
    end

    def url_for_event(eventlet)
      if eventlet.linkable.present?
        polymorphic_url(eventlet.linkable, **url_options)
      elsif eventlet.persisted?
        calendars_event_url(eventlet.event, **url_options)
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

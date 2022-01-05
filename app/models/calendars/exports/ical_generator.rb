# frozen_string_literal: true

require "icalendar"
require "icalendar/tzinfo"

module Calendars
  module Exports
    # Generates ICS files for various calendars in the system from a set of Event objects.
    class IcalGenerator
      include Rails.application.routes.url_helpers

      UID_SIGNATURE = "91a772a5ae4a"

      attr_accessor :calendar_name, :events, :cal, :url_options

      def initialize(calendar_name:, events:, url_options:)
        self.calendar_name = calendar_name
        self.events = events
        self.url_options = url_options
      end

      def generate
        self.cal = Icalendar::Calendar.new
        set_timezone
        events.each { |event| add_event(event) }
        cal.append_custom_property("X-WR-CALNAME", calendar_name)
        cal.publish
        cal.to_ical
      end

      private

      # `event` should be an Event object.
      def add_event(event)
        raise ArgumentError, "all events must specify uid" if event.uid.nil?

        cal.event do |e|
          # UID should be unique within the calendar. It is how the importing system determines which
          # events have changed when it refreshes the calendar.
          e.uid = [UID_SIGNATURE, event.uid].join("_")
          e.dtstart = date_or_time_value(event, :starts_at)
          e.dtend = date_or_time_value(event, :ends_at)
          e.location = event.location
          e.summary = event.name
          # Google calendar doesn't display the given ICS URL attribute it seems (as of 7/14/2018)
          # so we include it at the end of the description instead.
          e.description = [event.note, url_for_event(event)].compact.join("\n")
        end
      end

      def url_for_event(event)
        if event.linkable.present?
          polymorphic_url(event.linkable, **url_options)
        elsif event.persisted?
          calendars_event_url(event, **url_options)
        else
          raise ArgumentError, "unpersisted events must define linkable"
        end
      end

      # Return date or datetime depedning on if event is all_day
      def date_or_time_value(event, attrib)
        if event.all_day?
          # iCal format wants the day after the last day of the event as the end date for all day events.
          Icalendar::Values::Date.new(event[attrib] + (attrib == :ends_at ? 1 : 0).days)
        else
          Icalendar::Values::DateTime.new(event[attrib], tzid: tzid)
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
end

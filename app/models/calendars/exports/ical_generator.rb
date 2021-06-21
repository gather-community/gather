# frozen_string_literal: true

require "icalendar"
require "icalendar/tzinfo"

module Calendars
  module Exports
    # Generates ICS files for various calendars in the system from a Dataset object.
    class IcalGenerator
      UID_SIGNATURE = "91a772a5ae4a"

      attr_accessor :data, :cal

      # Takes a Dataset object.
      def initialize(data)
        self.data = data
      end

      def generate
        self.cal = Icalendar::Calendar.new
        set_timezone
        data.events.each { |event| add_event(event) }
        cal.append_custom_property("X-WR-CALNAME", data.calendar_name)
        cal.publish
        cal.to_ical
      end

      private

      # `event` should be an Event object.
      def add_event(event)
        cal.event do |e|
          e.uid = [UID_SIGNATURE, event.kind_name, event.obj_id, event.uid_suffix].compact.join("_")
          e.dtstart = date_or_time_value(event.starts_at)
          e.dtend = date_or_time_value(event.ends_at)
          e.location = event.location
          e.summary = event.summary
          # Google calendar doesn't display the given ICS URL attribute it seems (as of 7/14/2018)
          # so we include it at the end of the description instead.
          e.description = break_lines(Array.wrap(event.description) << event.url)
        end
      end

      # Source values may be Times or Dates, need to convert to appropriate Icalendar values.
      def date_or_time_value(source)
        if source.is_a?(Time)
          Icalendar::Values::DateTime.new(source, tzid: tzid)
        else
          Icalendar::Values::Date.new(source)
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

      # Pad each line in the array (except the last) to a multiple of 75 characters so that
      # it will be broken properly by the icalendar gem. Somewhat hackish.
      def break_lines(lines)
        regex = /\P{M}\p{M}*/u # The regex icalendar uses to split by character.
        lines = lines.compact
        padded = lines[0...-1].map.with_index do |line, i|
          line + " " * (75 - (line.scan(regex).size + (i.zero? ? 12 : 1)) % 75)
        end
        padded.push(lines[-1]).join
      end
    end
  end
end

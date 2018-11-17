# frozen_string_literal: true

require "icalendar"
require "icalendar/tzinfo"

module Calendars
  module Exports
    # Generates ICS files for various calendars in the system from a Dataset object.
    class Generator
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
          e.uid = "#{UID_SIGNATURE}_#{data.class_name}_#{event.object_id}"
          e.dtstart = Icalendar::Values::DateTime.new(event.starts_at, tzid: tzid)
          e.dtend = Icalendar::Values::DateTime.new(event.ends_at, tzid: tzid)
          e.location = event.location
          e.summary = event.summary
          # Google calendar doesn't display the given ICS URL attribute it seems (as of 7/14/2018)
          # so we include it at the end of the description instead.
          e.description = break_lines(Array.wrap(event.description) << event.url)
        end
      end

      # Sets up the calendar's timzeone blocks at the top of the file.
      # This is kind of a weird incantation taken from the gem docs.
      # Version 2 of the gem is supposed to have better timezone support, if it ever comes out.
      def set_timezone
        tz = TZInfo::Timezone.get(tzid)
        cal.add_timezone(tz.ical_timezone(data.sample_time || Time.current))
      end

      # Current timezone ID in tzinfo format.
      def tzid
        Time.zone.tzinfo.name
      end

      # Pad each line in the array (except the last) to a multiple of 75 characters so that
      # it will be broken properly by the icalendar gem. Somewhat hackish.
      def break_lines(lines)
        regex = /\P{M}\p{M}*/u # The regex icalendar uses to split by character.
        lines[0...-1].compact.each_with_index do |line, i|
          lines[i] += " " * (75 - (line.scan(regex).size + (i.zero? ? 12 : 1)) % 75)
        end
        lines.compact.join
      end
    end
  end
end

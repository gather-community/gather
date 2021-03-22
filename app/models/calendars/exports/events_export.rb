# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for event calendars of various sorts
    class EventsExport < Export
      # If all of these are the same for any N calendar events, we should group them together in the export.
      GROUP_ATTRIBS = %w[starts_at ends_at creator_id meal_id name].freeze

      def kind_name(_object)
        "Event"
      end

      protected

      def base_scope
        # calendar_id sort is for specs
        Calendars::EventPolicy::Scope.new(user, Calendars::Event).resolve
          .joins(:calendar, :creator).includes(:calendar, :creator)
          .with_max_age(MAX_EVENT_AGE).oldest_first.order(:calendar_id)
      end

      # Calendars::Event is different from Calendars::Exports::Event
      # May want to clarify this later.
      def events_for_objects(calendar_events)
        groups = calendar_events.group_by { |r| r.attributes.slice(*GROUP_ATTRIBS) }
        groups.map do |_, members|
          Event.new(basic_event_attribs(members[0]).merge(
            location: members.map(&:location_name).join(" + ")
          ))
        end
      end

      def summary(calendar_event)
        calendar_event.name << (calendar_event.meal? ? "" : " (#{calendar_event.creator_name})")
      end

      def url(calendar_event)
        url_for(calendar_event, :calendars_event_url)
      end
    end
  end
end

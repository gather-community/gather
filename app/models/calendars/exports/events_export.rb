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
          .joins(:calendar, :creator)
          .includes(:calendar, :creator)
          .where(calendar_nodes: {community_id: user.community_id})
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

      def starts_at(object)
        object.all_day? ? object.starts_at.to_date : object.starts_at
      end

      def ends_at(object)
        # iCal format wants the day after the last day of the event as the end date for all day events.
        object.all_day? ? object.ends_at.to_date + 1 : object.ends_at
      end
    end
  end
end

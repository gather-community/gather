# frozen_string_literal: true

module Calendars
  class EventletSerializer < ApplicationSerializer
    include LinkableUrls

    attributes :id, :event_id, :url, :title, :start, :end, :editable, :class_name,
      :calendar_allows_overlap, :calendar_id, :background_color, :border_color,
      :occurrence_start, :recurring, :eventlet_count, :calendar_name, :other_calendar_names,
      :eventlet_id

    def url
      if object.linkable.present?
        # linkable is the base eventlet for recurring occurrences (→ eventlet show page), or a
        # meal/shift/user for system calendars (→ that resource's page).
        if object.linkable.is_a?(Calendars::Eventlet)
          # origin_page lets the show page's edit/delete actions return to the combined view.
          calendars_eventlet_path(object.linkable, occurrence: object.occurrence_start&.to_i,
            origin_page: instance_options[:origin_page])
        else
          linkable_path(object.linkable)
        end
      elsif object.persisted?
        calendars_eventlet_path(object, origin_page: instance_options[:origin_page])
      else
        raise ArgumentError, "unpersisted eventlets must define linkable"
      end
    end

    def title
      object.name
    end

    def start
      object.all_day? ? object.starts_at.to_date.to_s : object.starts_at.to_fs(:no_zone)
    end

    # end is a reserved word
    define_method(:end) do
      object.all_day? ? (object.ends_at.to_date + 1).to_s : object.ends_at.to_fs(:no_zone)
    end

    def editable
      Calendars::EventletPolicy.new(scope, object).update?
    end

    # Unix timestamp identifying which occurrence of a series this is (the original, pre-override
    # start). Nil for non-recurring eventlets. The drag handler sends this back so the server knows
    # which occurrence to override.
    def occurrence_start
      object.occurrence_start&.to_i
    end

    # Drives the "this occurrence vs. the whole series" prompt on drag.
    def recurring
      series_event&.recurring? || false
    end

    # Drives the "this calendar vs. all calendars" prompt on drag. System calendar eventlets are
    # transient and never draggable, so they report 1.
    def eventlet_count
      series_event&.persisted? ? series_event.eventlets.size : 1
    end

    # The persisted eventlet a drag should write to. `id` can't serve this purpose: for a recurring
    # occurrence the serialized row is transient so its id is nil, and reusing the base eventlet's id
    # across occurrences would make FullCalendar treat them as one group and drag them together.
    def eventlet_id
      return object.id if object.persisted?
      object.linkable.is_a?(Calendars::Eventlet) ? object.linkable.id : nil
    end

    # calendar_name needs no method here; AMS falls through to Eventlet#calendar_name.

    # The other calendars this event appears on, named in the "move on all calendars" prompt so the
    # user can see exactly what else they're about to move.
    def other_calendar_names
      return [] unless series_event&.persisted?
      series_event.eventlets.reject { |e| e.calendar_id == object.calendar_id }
        .map(&:calendar_name).sort
    end

    def class_name
      if object.meal?
        "has-meal"
      elsif object.creator == scope
        object.group ? "own-group-event" : "own-event"
      else
        ""
      end
    end

    def calendar_allows_overlap
      object.calendar_allows_overlap?
    end

    def background_color
      object.color
    end

    def border_color
      background_color.paint.darken(5).to_hex
    end

    private

    # The real, persisted series event. A recurring occurrence's own `event` is a transient,
    # non-recurring display copy, so we reach the real one through linkable. Mirrors
    # EventletDecorator#series_event.
    def series_event
      object.linkable.is_a?(Calendars::Eventlet) ? object.linkable.event : object.event
    end
  end
end

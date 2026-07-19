# frozen_string_literal: true

module Calendars
  class EventletSerializer < ApplicationSerializer
    include Rails.application.routes.url_helpers

    attributes :id, :event_id, :url, :title, :start, :end, :editable, :class_name,
      :calendar_allows_overlap, :calendar_id, :background_color, :border_color,
      :occurrence_start, :recurring, :eventlet_count

    def url
      if object.linkable.present?
        # linkable is the base eventlet for recurring occurrences (→ eventlet show page), or a
        # meal/job/user for system calendars (→ that resource's page).
        polymorphic_path(object.linkable, occurrence: object.occurrence_start&.to_i)
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

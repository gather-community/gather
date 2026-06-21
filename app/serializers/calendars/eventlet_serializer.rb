# frozen_string_literal: true

module Calendars
  class EventletSerializer < ApplicationSerializer
    include Rails.application.routes.url_helpers

    attributes :id, :url, :title, :start, :end, :editable, :class_name, :calendar_allows_overlap,
      :calendar_id, :background_color, :border_color

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
  end
end

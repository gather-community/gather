# frozen_string_literal: true

# For calendars.
module Calendars
  class EventSerializer < ApplicationSerializer
    include Rails.application.routes.url_helpers

    attributes :id, :url, :title, :start, :end, :editable, :class_name, :calendar_allows_overlap,
               :calendar_id, :background_color, :border_color

    def url
      if object.linkable.present?
        polymorphic_path(object.linkable)
      elsif object.persisted?
        calendars_event_path(object, origin_page: instance_options[:origin_page])
      else
        raise ArgumentError, "unpersisted events must define linkable"
      end
    end

    def title
      object.name
    end

    def start
      # We don't include timezone in the format because the calendar doesn't have timezone
      # set either so we want everything to be ambiguously zoned and let the server
      # assume all incoming events are in the community's zone. The only reason we'd need
      # zone is if we someday wanted to mix times from several zones on the calendar but
      # we don't and can't foresee needing to.
      object.all_day? ? object.starts_at.to_date.to_s : object.starts_at.to_fs(:no_zone)
    end

    # end is a reserved word
    define_method(:end) do
      object.all_day? ? (object.ends_at.to_date + 1).to_s : object.ends_at.to_fs(:no_zone)
    end

    def editable
      # scope == current_user
      Calendars::EventPolicy.new(scope, object).edit?
    end

    def class_name
      if object.meal
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

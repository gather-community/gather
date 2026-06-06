# frozen_string_literal: true

module Calendars
  # A virtual, non-persisted occurrence of a recurring event. Duck-types as Eventlet for use
  # in serializers, policies, and the iCal generator.
  class RecurringOccurrence
    delegate :name, :kind, :meal?, :meal_id, :creator, :creator_id, :group, :note,
      :all_day, :all_day?, :community, :community_id, :color,
      :calendar, :calendar_id, :calendar_allows_overlap?, :rule_set,
      :recently_created?, :location, :linkable, to: :@eventlet
    delegate :event_id, :event, to: :@eventlet

    attr_reader :starts_at, :ends_at

    def initialize(eventlet, starts_at, ends_at)
      @eventlet = eventlet
      @starts_at = starts_at
      @ends_at = ends_at
    end

    # Stable string ID combining event ID and occurrence time. Used by serializer and iCal.
    def id
      "#{event_id}_#{starts_at.to_i}"
    end

    def uid
      id
    end

    # The underlying event is persisted; enables URL generation in serializer and IcalGenerator.
    def persisted?
      true
    end

    def future?
      starts_at.future?
    end

    def single_day?
      ends_at.to_date == starts_at.to_date
    end

    def seconds
      ends_at - starts_at
    end

    def minutes
      (seconds.to_f / 1.minute).ceil
    end

    def days
      (seconds.to_f / 1.day).ceil
    end
  end
end

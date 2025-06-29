# frozen_string_literal: true

module Calendars
  class Eventlet < ApplicationRecord
    acts_as_tenant :cluster

    attr_accessor :guidelines_ok
    attr_writer :location

    belongs_to :event, class_name: "Calendars::Event", inverse_of: :eventlets
    belongs_to :calendar, class_name: "Calendars::Calendar", inverse_of: :eventlets

    delegate :kind, to: :event

    delegate :community_id, :color, to: :calendar
    delegate :name, to: :calendar, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    scope :between, ->(range) { where("starts_at < ? AND ends_at > ?", range.last, range.first) }

    before_validation :normalize

    def uid
      # System calendars that make unpersisted events should set
      # uid or the export process will raise an error.
      persisted? ? id : @uid
    end

    # Location is an ephemeral attribute for now because you can't set it in the UI but it's useful for
    # exports. Usually the location is just the calendar name. But system calendars may want to set a more
    # useful location like the location of a meal or a job. We might make this available in the form later.
    def location
      # Explicit location will always be returned if it's set.
      @location || (persisted? ? calendar_name : nil)
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

    def future?
      starts_at.try(:future?)
    end

    def recently_created?
      Time.current - created_at < 1.hour
    end

    def guidelines_ok?
      guidelines_ok == "1"
    end

    def single_day?
      ends_at.to_date == starts_at.to_date
    end

    def calendar_allows_overlap?
      calendar.allow_overlap?
    end

    private

    def normalize
      self.all_day = false if rule_set.timed_events_only?
      return unless all_day?
      self.starts_at = starts_at.midnight
      self.ends_at = ends_at.midnight + 1.day - 1.second
    end

    # RuleSet needs to know `kind` to give a definitive answer on event permissions.
    # At event grid or event form load time, kind isn't known,
    # so some rules can't be applied until event submission.
    # But many protocols don't involve kind, and for those we can use the RuleSet to show things
    # about the RuleSet in the UI like the event form or the event grid.
    # In those cases, we can use a sample Event object with nil kind.
    def rule_set
      # Don't memoize this, it causes all kinds of bugs. Worth the performance hit.
      Rules::RuleSet.build_for(calendar: calendar, kind: kind)
    end
  end
end
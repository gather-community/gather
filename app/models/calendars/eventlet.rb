# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_eventlets
#
#  id          :bigint           not null, primary key
#  cluster_id  :bigint           not null
#  event_id    :bigint           not null
#  calendar_id :bigint           not null
#  starts_at   :datetime         not null
#  ends_at     :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
module Calendars
  class Eventlet < ApplicationRecord
    acts_as_tenant :cluster

    attr_accessor :guidelines_ok

    # For system calendar event exports. See the reader method below.
    attr_writer :uid

    # For system calendars event exports. See the reader method below.
    attr_writer :location

    # Used by system calendars. Holds either a URL or
    # an object that this event should link to.
    # objects are preferred so that the system calendar classes don't have to be responsible
    # for generating URLs/paths.
    attr_accessor :linkable

    belongs_to :event, class_name: "Calendars::Event", inverse_of: :eventlets
    belongs_to :calendar, class_name: "Calendars::Calendar", inverse_of: :eventlets

    delegate :name, :kind, :meal?, :meal_id, :creator, :creator_id, :group, :note, to: :event
    delegate :all_day, :all_day?, to: :event

    # Satisfies ducktype expected by policies. Prefer more explicit variants creator_community
    # and sponsor_community on Event for other uses.
    delegate :community, to: :calendar, allow_nil: true

    delegate :community_id, :color, to: :calendar
    delegate :name, to: :calendar, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    # Specifying the table name here is temporarily required for some queries because calendar_events also has these columns.
    scope :between, ->(range) { where("calendar_eventlets.starts_at < ? AND calendar_eventlets.ends_at > ?", range.last, range.first) }

    before_validation :normalize
    validate :all_day_permitted

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

    private

    def all_day_permitted
      errors.add(:all_day, :not_allowed) if all_day? && rule_set.timed_events_only?
    end

    def normalize
      return unless all_day?
      self.starts_at = starts_at.midnight
      self.ends_at = ends_at.midnight + 1.day - 1.second
    end
  end
end

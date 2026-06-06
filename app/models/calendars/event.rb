# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_events
#
#  id                  :integer          not null, primary key
#  all_day             :boolean          default(FALSE), not null
#  calendar_id         :integer          not null
#  cluster_id          :integer          not null
#  created_at          :datetime         not null
#  creator_id          :integer
#  ends_at             :datetime         not null
#  group_id            :bigint
#  kind                :string
#  meal_id             :integer
#  name                :string(24)       not null
#  note                :text
#  recurrence_end_date :date
#  recurrence_rule     :jsonb
#  sponsor_id          :integer
#  starts_at           :datetime         not null
#  updated_at          :datetime         not null
#
module Calendars
  class Event < ApplicationRecord
    acts_as_tenant :cluster

    attr_writer :location

    # Temporary accessor used only by the Eventlet factory. Without this, we were creating duplicate
    # Eventlets because the factory would build the parent Event, which would build its own Eventlet,
    # and then the factory would then build its own Eventlet.
    #
    # Once we are done splitting Eventlet out from Event, we can remove both this attribute and the
    # sync_eventlet method.
    attr_accessor :dont_sync_eventlet

    # linkable is used by system calendars and holds either a URL or
    # an object that this event should link to.
    # objects are preferred so that the system calendar classes don't have to be responsible
    # for generating URLs/paths.
    attr_accessor :linkable

    attr_writer :uid

    has_many :eventlets, inverse_of: :event, dependent: :destroy, autosave: true
    belongs_to :creator, class_name: "User"
    belongs_to :sponsor, class_name: "User"
    belongs_to :calendar, inverse_of: :events
    belongs_to :meal, class_name: "Meals::Meal", inverse_of: :events
    belongs_to :group, class_name: "Groups::Group", inverse_of: :events

    scope :between, ->(range) { where("starts_at < ? AND ends_at > ?", range.last, range.first) }
    scope :related_to, ->(user) { where(creator: user).or(where(sponsor: user)) }

    # Satisfies ducktype expected by policies. Prefer more explicit variants creator_community
    # and sponsor_community for other uses.
    delegate :community, to: :calendar, allow_nil: true

    delegate :community_id, :color, to: :calendar
    delegate :name, to: :calendar, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    delegate :household, to: :creator
    delegate :users, to: :household, prefix: true
    delegate :name, :community, to: :creator, prefix: true
    delegate :community, to: :sponsor, prefix: true, allow_nil: true

    before_validation :normalize_all_day_times

    # Temporary method to dual write Eventlet model
    before_save :sync_eventlet
    before_save :compute_recurrence_end_date

    before_save lambda { |r| meal&.event_handler&.sync_resourcings(r) }

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

    def displayable_kind?
      kind.present? && !meal?
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

    def future?
      starts_at.try(:future?)
    end

    def recently_created?
      Time.current - created_at < 1.hour
    end

    def single_day?
      ends_at.to_date == starts_at.to_date
    end

    def meal?
      # We add an underscore to differentiate from user-specified kinds
      kind == "_meal"
    end

    def calendar_allows_overlap?
      calendar.allow_overlap?
    end

    def recurring?
      recurrence_rule.present?
    end

    # Returns an IceCube::Schedule anchored at starts_at with the stored recurrence rule.
    def schedule
      return nil unless recurring?
      IceCube::Schedule.new(starts_at).tap do |s|
        s.add_recurrence_rule(IceCube::Rule.from_hash(recurrence_rule))
      end
    end

    # Returns an array of [occ_starts_at, occ_ends_at] pairs for each occurrence in the given range.
    def occurrences_between(range)
      return [] unless recurring?
      duration = ends_at - starts_at
      schedule.occurrences_between(range.first, range.last).map { |t| [t, t + duration] }
    end

    private

    def normalize_all_day_times
      return unless all_day?
      self.starts_at = starts_at.midnight
      self.ends_at = ends_at.midnight + 1.day - 1.second
    end

    def compute_recurrence_end_date
      return self.recurrence_end_date = nil unless recurring?
      # Rebuild via ice_cube so we get consistent symbol-keyed hashes regardless of whether
      # recurrence_rule came from in-memory assignment (symbol keys) or a JSONB read (string keys).
      rule_hash = schedule.rrules.first.to_hash
      self.recurrence_end_date = if rule_hash[:until]
        # ice_cube serializes time values as {time: <Time>, zone: "..."}
        ice_time = rule_hash[:until]
        (ice_time.is_a?(Hash) ? ice_time[:time] : ice_time).to_date
      elsif rule_hash[:count]
        schedule.last&.to_date
      end
    end

    def sync_eventlet
      return if dont_sync_eventlet

      # Ensure only one
      (eventlets[1..] || []).each(&:destroy)
      eventlet = eventlets[0] || eventlets.build

      eventlet.event_id = id
      eventlet.calendar_id = calendar_id
    end
  end
end

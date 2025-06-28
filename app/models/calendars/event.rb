# frozen_string_literal: true

module Calendars
  class Event < ApplicationRecord
    NAME_MAX_LENGTH = 24

    acts_as_tenant :cluster

    attr_accessor :guidelines_ok, :privileged_changer, :origin_page
    attr_writer :location

    # linkable is used by system calendars and holds either a URL or
    # an object that this event should link to.
    # objects are preferred so that the system calendar classes don't have to be responsible
    # for generating URLs/paths.
    attr_accessor :linkable

    attr_writer :uid
    alias_method :privileged_changer?, :privileged_changer

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

    validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
    validates :calendar_id, :starts_at, :ends_at, presence: true
    validates :creator_id, presence: true, unless: ->(e) { e.meal? }
    validate :guidelines_accepted
    validate :start_before_end
    validate :restrict_changes_in_past
    validate :no_overlap
    validate :apply_rules
    validate lambda { |r| meal&.event_handler&.validate_event(r) }

    # Temporary method to dual write Eventlet model
    before_validation :sync_eventlet

    before_validation :normalize

    before_save lambda { |r| meal&.event_handler&.sync_resourcings(r) }

    normalize_attributes :kind, :note

    def self.new_with_defaults(attribs)
      event = new(attribs)

      event.starts_at ||= Time.current.midnight + 1.week + 17.hours
      event.ends_at ||= Time.current.midnight + 1.week + 18.hours

      # Set fixed start/end time
      rule_set = event.rule_set
      if fst = rule_set.fixed_start_time
        event.starts_at = event.starts_at.change(hour: fst.hour, min: fst.min)
      end
      if fet = rule_set.fixed_end_time
        event.ends_at = event.ends_at.change(hour: fet.hour, min: fet.min)
      end
      event.ends_at += 1.day if event.starts_at >= event.ends_at

      event
    end

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

    def guidelines_ok?
      guidelines_ok == "1"
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

    private

    def sync_eventlet
      # Ensure only one
      (eventlets[1..-1] || []).each(&:destroy)
      eventlet = eventlets[0] || eventlets.build

      eventlet.event_id = id
      eventlet.calendar_id = calendar_id
      eventlet.starts_at = starts_at
      eventlet.ends_at = ends_at
    end

    def normalize
      self.all_day = false if rule_set.timed_events_only?
      return unless all_day?
      self.starts_at = starts_at.midnight
      self.ends_at = ends_at.midnight + 1.day - 1.second
    end

    def guidelines_accepted
      return unless new_record? && calendar.guidelines? && !guidelines_ok?
      errors.add(:guidelines, "You must agree to the guidelines")
    end

    def start_before_end
      return unless starts_at.present? && ends_at.present? && starts_at >= ends_at
      errors.add(:ends_at, "must be after start time")
    end

    def no_overlap
      return if calendar_allows_overlap? || starts_at.blank? || ends_at.blank?
      query = self.class.between(starts_at..ends_at)
      query = query.where(calendar_id: calendar_id)
      query = query.where("id != #{id}") if persisted?
      errors.add(:base, "This event overlaps an existing one") if query.any?
    end

    def apply_rules
      return if errors.any?
      rule_set.errors(self).each { |e| errors.add(*e) }
    end

    def restrict_changes_in_past
      return unless persisted? && !recently_created? && !privileged_changer?
      if will_save_change_to_starts_at? && starts_at_was&.past?
        errors.add(:starts_at, "can't be changed after event begins")
      end
      if will_save_change_to_ends_at? && ends_at&.past? # rubocop:disable Style/GuardClause # || structure
        errors.add(:ends_at, "can't be changed to a time in the past")
      end
    end
  end
end

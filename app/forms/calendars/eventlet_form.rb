# frozen_string_literal: true

module Calendars
  # Handles a drag-and-drop time change to a single eventlet in the calendar grid.
  #
  # A drag carries two independent scope choices, and the four combinations map onto four different
  # rows:
  #
  #                  | series scope            | occurrence scope
  #   ---------------|-------------------------|--------------------------------
  #   all calendars  | Event#starts_at/ends_at  | EventOverride#starts_at/ends_at
  #   this calendar  | Eventlet#*_offset        | EventletOverride#*_offset
  #
  # "All calendars" moves the underlying event, carrying every eventlet with it, so the dragged
  # eventlet's own offsets are subtracted to work out where the event itself has to land for the
  # dragged eventlet to end up where it was dropped. "This calendar" leaves the event alone and
  # changes only this eventlet's offsets.
  #
  # The client sends the dropped absolute times; all offsets are computed here.
  class EventletForm
    CALENDAR_SCOPES = %w[this all].freeze
    SERIES_SCOPES = %w[series occurrence].freeze

    include ActiveModel::Conversion
    include ActiveModel::Validations

    attr_reader :eventlet, :starts_at, :ends_at, :occurrence_start, :calendar_scope, :series_scope

    delegate :event, :calendar, to: :eventlet

    validates :starts_at, :ends_at, presence: true
    validates :calendar_scope, inclusion: {in: CALENDAR_SCOPES}
    validates :series_scope, inclusion: {in: SERIES_SCOPES}
    validate :start_before_end
    validate :occurrence_present_when_needed
    validate :offsets_within_range
    validate :restrict_changes_in_past
    validate :no_overlap
    validate :apply_rules

    def self.model_name
      Calendars::Eventlet.model_name
    end

    def initialize(eventlet:, current_user: nil, params: {})
      @eventlet = eventlet
      @current_user = current_user
      params = params.permit(eventlet_policy.permitted_attributes) if params.respond_to?(:permit)
      @starts_at = parse_time(params[:starts_at])
      @ends_at = parse_time(params[:ends_at])
      # FullCalendar reports an all-day event's end as the exclusive day-after-midnight, but we store
      # an inclusive end (23:59:59 on the last day). Pull it back so a dragged all-day event lands on
      # the right day instead of gaining a day. A drag never changes whether an event is all-day, so
      # this keys off the event's existing flag rather than anything the client sends.
      @ends_at -= 1.second if @ends_at && event.all_day?
      @occurrence_start = parse_unix(params[:occurrence_start])
      @calendar_scope = params[:calendar_scope].presence || "all"
      @series_scope = params[:series_scope].presence || "series"
    end

    def save
      return false unless valid?

      case [calendar_scope, series_scope]
      when %w[all series] then move_event
      when %w[all occurrence] then move_occurrence
      when %w[this series] then move_eventlet
      when %w[this occurrence] then move_eventlet_occurrence
      end
    end

    def persisted?
      true
    end

    private

    attr_reader :current_user

    # === Write paths ===

    # Moves the whole series on every calendar. Delegates to EventForm so the event-level rules
    # (overlap, meal handling, protocol rules, past restriction) all still apply.
    def move_event
      # EventForm parses its times from strings.
      form = EventForm.new(action: :update, current_user: current_user, id: event.id,
        params: {starts_at: event_starts_at.iso8601, ends_at: event_ends_at.iso8601})
      return true if form.save
      form.errors.each { |e| errors.add(e.attribute, e.message) }
      false
    end

    # Moves one occurrence on every calendar, leaving the rest of the series alone.
    def move_occurrence
      override = find_or_initialize_event_override
      override.starts_at = event_starts_at
      override.ends_at = event_ends_at
      persist(override)
    end

    # Moves the whole series on this calendar only, by shifting this eventlet's offsets.
    def move_eventlet
      eventlet.start_offset = dragged_start_offset
      eventlet.end_offset = dragged_end_offset
      persist(eventlet)
    end

    # Moves one occurrence on this calendar only. EventletOverride requires a parent EventOverride,
    # so an anchor row is created for the occurrence if one doesn't already exist. The anchor carries
    # no time change of its own; it exists purely to hold the occurrence_start identity.
    def move_eventlet_occurrence
      anchor = find_or_initialize_event_override
      return false unless persist(anchor)

      override = anchor.eventlet_overrides.detect { |o| o.eventlet_id == eventlet.id } ||
        anchor.eventlet_overrides.build(eventlet: eventlet)
      override.start_offset = dragged_start_offset
      override.end_offset = dragged_end_offset
      persist(override)
    end

    def persist(record)
      return true if record.save
      record.errors.each { |e| errors.add(e.attribute, e.message) }
      false
    end

    def find_or_initialize_event_override
      existing_event_override ||
        event.event_overrides.build(occurrence_start: occurrence_start)
    end

    def existing_event_override
      # Matched on unix seconds rather than by equality, mirroring OccurrenceResolver, so sub-second
      # drift in the stored value can't cause a duplicate override.
      return nil if occurrence_start.blank?
      event.event_overrides.detect { |o| o.occurrence_start.to_i == occurrence_start.to_i }
    end

    # === Time math ===

    # Where the event itself has to land for the dragged eventlet to end up where it was dropped.
    def event_starts_at
      starts_at - eventlet.start_offset.seconds
    end

    def event_ends_at
      ends_at - eventlet.end_offset.seconds
    end

    # The occurrence's event-level times, before this eventlet's offsets are applied. An existing
    # EventOverride may already have moved the occurrence; otherwise it sits at its scheduled slot.
    def occurrence_base_starts_at
      existing_event_override&.starts_at || occurrence_start
    end

    def occurrence_base_ends_at
      existing_event_override&.ends_at || (occurrence_start + event_duration)
    end

    def event_duration
      event.ends_at - event.starts_at
    end

    # This eventlet's offsets for a this-calendar drag: how far the dropped times sit from the base
    # this drag is measured against. The whole series measures against the event; a single occurrence
    # measures against that occurrence's (possibly already-overridden) times.
    def dragged_start_offset
      base = (series_scope == "occurrence") ? occurrence_base_starts_at : event.starts_at
      (starts_at - base).round
    end

    def dragged_end_offset
      base = (series_scope == "occurrence") ? occurrence_base_ends_at : event.ends_at
      (ends_at - base).round
    end

    # === Validations ===

    def start_before_end
      return if starts_at.blank? || ends_at.blank?
      errors.add(:ends_at, "must be after start time") if starts_at >= ends_at
    end

    def occurrence_present_when_needed
      return unless series_scope == "occurrence"
      if occurrence_start.blank?
        errors.add(:occurrence_start, "is required to change a single occurrence")
      elsif !event.recurring?
        errors.add(:base, "This event is not part of a series")
      elsif !event.schedule.occurs_at?(occurrence_start)
        errors.add(:occurrence_start, "is not a valid occurrence in this series")
      end
    end

    # A this-calendar drag is stored as an offset from the event's shared time, and both Eventlet and
    # EventletOverride cap that offset at MAX_OFFSET_SECONDS so the eventlet stays inside the window the
    # grid query pre-filters on. Catch an over-cap drag here so the user gets a plain explanation
    # instead of the raw "start offset is not included in the list" model error. All-calendars drags
    # move the event itself and have no such cap, so they're left alone.
    def offsets_within_range
      return if errors.any? || calendar_scope != "this"
      return if starts_at.blank? || ends_at.blank?
      max = Eventlet::MAX_OFFSET_SECONDS
      return if dragged_start_offset.abs <= max && dragged_end_offset.abs <= max
      errors.add(:base, "An event's times on its different calendars can't be more than " \
        "#{max / 1.hour} hours apart. To move it further, choose “Move on all calendars.”")
    end

    # Mirrors EventForm#restrict_changes_in_past. Meal events are exempt because they're maintained
    # by the meal event handler rather than by hand.
    def restrict_changes_in_past
      return if eventlet.meal? || eventlet_policy.privileged_change?
      return if eventlet.recently_created?
      errors.add(:starts_at, "can't be changed after event begins") if eventlet.starts_at&.past?
      errors.add(:ends_at, "can't be changed to a time in the past") if ends_at&.past?
    end

    # Overlap is checked at the eventlet level rather than the event level, since two eventlets on
    # the same calendar are what actually collide in the grid.
    def no_overlap
      return if errors.any? || calendar.allow_overlap?
      clashes = Eventlet.between(starts_at..ends_at)
        .where(calendar_id: eventlet.calendar_id)
        .where.not(id: eventlet.id)
      errors.add(:base, "This event overlaps an existing one") if clashes.any?
    end

    # Runs the calendar's protocol rules against a stand-in event carrying the dropped times, so an
    # eventlet drag is held to the same rules as an edit through the event form.
    def apply_rules
      return if errors.any?
      eventlet.rule_set.errors(proxy_event).each { |e| errors.add(*e) }
    end

    def proxy_event
      Event.new(name: event.name, kind: event.kind, all_day: event.all_day, creator: event.creator,
        group: event.group, meal_id: event.meal_id, calendar: calendar,
        starts_at: starts_at, ends_at: ends_at)
    end

    # === Misc ===

    def eventlet_policy
      @eventlet_policy ||= EventletPolicy.new(current_user, eventlet)
    end

    def parse_time(value)
      return value if value.blank? || value.is_a?(Time)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_unix(value)
      return nil if value.blank?
      Time.zone.at(value.to_i)
    end
  end
end

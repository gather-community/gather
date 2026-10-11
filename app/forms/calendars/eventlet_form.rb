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
  # "All calendars" moves the underlying event, carrying every eventlet with it. "This calendar" leaves
  # the event alone and changes only this eventlet's offsets.
  #
  # The client sends the dropped absolute times; all offsets are computed here. A series-scope drag is
  # measured from the occurrence that was dragged, which for a recurring event needn't be the first,
  # and moves every occurrence by that same distance.
  class EventletForm
    CALENDAR_SCOPES = %w[this all].freeze
    SERIES_SCOPES = %w[series occurrence].freeze

    include ActiveModel::Conversion
    include ActiveModel::Validations
    include OccurrenceOverrides

    attr_reader :eventlet, :starts_at, :ends_at, :occurrence_start, :calendar_scope, :series_scope

    delegate :event, :calendar, to: :eventlet

    validates :starts_at, :ends_at, presence: true
    validates :calendar_scope, inclusion: {in: CALENDAR_SCOPES}
    validates :series_scope, inclusion: {in: SERIES_SCOPES}
    validate :start_before_end
    validate :occurrence_resolvable
    validate :offsets_within_range
    validate :restrict_changes_in_past
    validate :restrict_series_moves_after_start
    validate :series_pattern_allows_move
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

      # A write path can touch more than one row (the event, then the dragged occurrence's override),
      # so a failure partway through must undo the rest. Paths report failure by returning false.
      ActiveRecord::Base.transaction do
        saved =
          case [calendar_scope, series_scope]
          when %w[all series] then move_event
          when %w[all occurrence] then move_occurrence
          when %w[this series] then move_eventlet
          when %w[this occurrence] then move_eventlet_occurrence
          end
        raise ActiveRecord::Rollback unless saved
        true
      end || false
    end

    def persisted?
      true
    end

    private

    attr_reader :current_user

    # === Occurrence lookup ===

    # The dragged eventlet as it stood before the drag, with any overrides applied. A non-recurring
    # event's only "occurrence" is the eventlet itself. Nil for a recurring event whose occurrence is
    # missing or no longer exists (e.g. deleted in another tab).
    def occurrence
      return @occurrence if defined?(@occurrence)
      @occurrence =
        if !event.recurring?
          eventlet
        elsif occurrence_start
          OccurrenceResolver.new(eventlet, occurrence_start.to_i).resolve
        end
    end

    def recurring_series_move?
      series_scope == "series" && event.recurring?
    end

    # This calendar's own override of the dragged occurrence, if it has one.
    def dragged_eventlet_override
      existing_event_override&.eventlet_overrides&.detect { |o| o.eventlet_id == eventlet.id }
    end

    # === Write paths ===

    # Moves every occurrence on every calendar by the drag distance. Delegates to EventForm so the
    # event-level rules (overlap, meal handling, protocol rules, past restriction) all still apply.
    # Event's own callbacks re-key the series' overrides and shift its UNTIL to match.
    def move_event
      # Loaded before the event moves; Event re-keys these same records in place when it saves.
      dragged_override = existing_event_override if event.recurring?
      form = EventForm.new(action: :update, current_user: current_user, event: event,
        params: {starts_at: start_shift.apply(event.starts_at).iso8601,
                 ends_at: end_shift.apply(event.ends_at).iso8601})
      unless form.save
        form.errors.each { |e| errors.add(e.attribute, e.message) }
        return false
      end

      # An occurrence that was already moved on all calendars keeps its own time when the series
      # moves, so it needs the same shift to land where it was dropped.
      return true unless dragged_override&.starts_at
      dragged_override.starts_at = start_shift.apply(dragged_override.starts_at)
      dragged_override.ends_at = end_shift.apply(dragged_override.ends_at)
      persist(dragged_override)
    end

    # Moves one occurrence on every calendar, leaving the rest of the series alone. The occurrence's
    # own offsets on this calendar (which may come from an EventletOverride) are subtracted to work
    # out where the occurrence itself has to land for this eventlet to end up where it was dropped.
    def move_occurrence
      override = find_or_initialize_event_override
      override.starts_at = starts_at - occurrence.start_offset.seconds
      override.ends_at = ends_at - occurrence.end_offset.seconds
      persist(override)
    end

    # Moves every occurrence on this calendar only, by shifting this eventlet's offsets.
    def move_eventlet
      override = dragged_eventlet_override
      eventlet.start_offset, eventlet.end_offset = series_offsets
      return false unless persist(eventlet)
      return true unless override

      # The dragged occurrence's own offsets on this calendar replace the eventlet's, so they need
      # the same change for it to land where it was dropped.
      override.start_offset, override.end_offset = dragged_override_offsets
      persist(override)
    end

    # Moves one occurrence on this calendar only. EventletOverride requires a parent EventOverride,
    # so an anchor row is created for the occurrence if one doesn't already exist. The anchor carries
    # no time change of its own; it exists purely to hold the occurrence_start identity.
    def move_eventlet_occurrence
      anchor = find_or_initialize_event_override
      return false unless persist(anchor)

      override = find_or_initialize_eventlet_override(anchor)
      override.start_offset, override.end_offset = occurrence_offsets
      persist(override)
    end

    def persist(record)
      return true if record.save
      record.errors.each { |e| errors.add(e.attribute, e.message) }
      false
    end

    # === Time math ===

    # The drag as wall-clock moves of the dragged occurrence's start and end. A drop moves both the
    # same; a resize moves only the end. Measured on the displayed times, so the eventlet's offsets
    # are on both sides and cancel out.
    def start_shift
      @start_shift ||= WallClockShift.new(occurrence.starts_at, starts_at)
    end

    def end_shift
      @end_shift ||= WallClockShift.new(occurrence.ends_at, ends_at)
    end

    # How far the drag moves the dragged eventlet, in seconds. Offsets are fixed durations rather
    # than clock readings, so a plain difference is right for them.
    def start_delta
      (starts_at - occurrence.starts_at).round
    end

    def end_delta
      (ends_at - occurrence.ends_at).round
    end

    # This eventlet's new offsets for a this-calendar series drag.
    def series_offsets
      [eventlet.start_offset + start_delta, eventlet.end_offset + end_delta]
    end

    # The dragged occurrence's own override offsets after a this-calendar series drag. An offset the
    # override doesn't set falls back to the eventlet's, which is already moving, so it stays unset.
    def dragged_override_offsets
      override = dragged_eventlet_override
      [override.start_offset&.+(start_delta), override.end_offset&.+(end_delta)]
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

    # This eventlet's offsets for a this-calendar occurrence drag: how far the dropped times sit from
    # that occurrence's (possibly already-overridden) event-level times.
    def occurrence_offsets
      [(starts_at - occurrence_base_starts_at).round, (ends_at - occurrence_base_ends_at).round]
    end

    # Every offset a this-calendar drag would write, so they can be checked before any is.
    def offsets_to_write
      return occurrence_offsets if series_scope == "occurrence"
      offsets = series_offsets
      offsets += dragged_override_offsets.compact if dragged_eventlet_override
      offsets
    end

    # === Validations ===

    def start_before_end
      return if starts_at.blank? || ends_at.blank?
      errors.add(:ends_at, "must be after start time") if starts_at >= ends_at
    end

    # Every drag of a recurring event is measured from the dragged occurrence, so it has to be named
    # and still exist. A single-occurrence drag also needs the event to be recurring at all.
    def occurrence_resolvable
      return unless event.recurring? || series_scope == "occurrence"
      validate_occurrence_in_series
      return if errors.any? || occurrence
      errors.add(:base, "This occurrence no longer exists. Reload the calendar and try again.")
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
      return if offsets_to_write.all? { |offset| offset.abs <= max }
      errors.add(:base, "An event's times on its different calendars can't be more than " \
        "#{max / 1.hour} hours apart. To move it further, choose “Move on all calendars.”")
    end

    # Mirrors EventForm#restrict_changes_in_past, but for the dragged occurrence rather than the
    # series as a whole. Meal events are exempt because they're maintained by the meal event handler
    # rather than by hand.
    def restrict_changes_in_past
      return if occurrence.nil? || eventlet.meal? || eventlet_policy.privileged_change?
      return if eventlet.recently_created?
      errors.add(:starts_at, "can't be changed after event begins") if occurrence.starts_at.past?
      errors.add(:ends_at, "can't be changed to a time in the past") if ends_at&.past?
    end

    # Moving every occurrence of a series that has started would move past ones too, which nobody,
    # admins included, should do as a side effect. "Started" goes by the schedule's first slot, so a
    # series whose first occurrence was deleted or moved later still counts.
    def restrict_series_moves_after_start
      return unless recurring_series_move?
      return if event.recently_created? || !event.starts_at.past?
      errors.add(:base, "This series has already started, so moving all occurrences would change " \
        "past ones. Choose “This only” to move one occurrence.")
    end

    # A rule pinned to particular days or times (e.g. "every Tuesday") can't follow its start to a
    # slot the pattern excludes: the series would stay put and its overrides would no longer line up.
    def series_pattern_allows_move
      return if errors.any? || !(recurring_series_move? && calendar_scope == "all")
      new_start = start_shift.apply(event.starts_at)
      # The UNTIL moves along with the start, so only the pattern itself is checked.
      rule = IceCube::Rule.from_hash(event.recurrence_rule).until(nil)
      return if IceCube::Schedule.new(new_start) { |s| s.add_recurrence_rule(rule) }.occurs_at?(new_start)
      errors.add(:base, "This series repeats in a fixed pattern that doesn't include the new time, " \
        "so all its occurrences can't be moved there. Choose “This only” to move one occurrence.")
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
  end
end

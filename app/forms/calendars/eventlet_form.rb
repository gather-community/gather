# frozen_string_literal: true

module Calendars
  # Handles a drag-and-drop time change to a single eventlet in the calendar grid.
  #
  # A drag carries two independent scope choices. The calendar scope picks between moving the
  # underlying event, carrying every eventlet with it ("all"), and changing only this eventlet's
  # offsets ("this"). The series scope picks which occurrences of a recurring event move:
  #
  #                  | occurrence               | following                  | series
  #   ---------------|--------------------------|----------------------------|-------------------------
  #   all calendars  | EventOverride times      | split off a new, moved     | Event#starts_at/ends_at
  #                  |                          | series from here           |
  #   this calendar  | EventletOverride offsets | split, then change the new | Eventlet#*_offset
  #                  |                          | series' eventlet offsets   |
  #
  # The client sends the dropped absolute times; all offsets are computed here. Every drag is
  # measured from the occurrence that was dragged, which for a recurring event needn't be the first,
  # and a following- or series-scope drag moves every affected occurrence by that same distance.
  #
  # Which choices to offer is worked out here too (.allowed_choices), so the rules live in one place.
  class EventletForm
    CALENDAR_SCOPES = %w[this all].freeze
    SERIES_SCOPES = %w[occurrence following series].freeze

    # The checks that don't depend on where the eventlet is dropped, so they can decide which choices
    # to offer before the drag is submitted. See #permitted?.
    CHOICE_CHECKS = %i[occurrence_resolvable scope_combination_allowed restrict_all_calendars_to_editors
      restrict_changes_in_past restrict_series_moves_after_start restrict_following_from_past].freeze

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
    validate :scope_combination_allowed
    validate :restrict_all_calendars_to_editors
    validate :offsets_within_range
    validate :restrict_changes_in_past
    validate :restrict_drop_in_past
    validate :restrict_series_moves_after_start
    validate :restrict_following_from_past
    validate :series_pattern_allows_move
    validate :no_overlap
    validate :apply_rules

    def self.model_name
      Calendars::Eventlet.model_name
    end

    # The scope combinations the given user may choose for this eventlet/occurrence right now, as
    # {"this" => [series scopes...], "all" => [series scopes...]}. Drives the drag modal's options.
    def self.allowed_choices(eventlet:, occurrence_start:, user:)
      multi_calendar = eventlet.event.eventlets.size > 1
      CALENDAR_SCOPES.index_with do |calendar_scope|
        # The calendar question is only asked when there's more than one calendar.
        next [] if calendar_scope == "this" && !multi_calendar
        SERIES_SCOPES.select do |series_scope|
          form = for_choice(eventlet, occurrence_start, user, calendar_scope, series_scope)
          # "Following" from the first occurrence is the same as all of them, so don't offer both.
          form.series_scope == form.effective_series_scope && form.permitted?
        end
      end
    end

    # A form for the plainest move of this eventlet (one occurrence, or the event itself), with
    # errors saying why it can't be moved. For when .allowed_choices offers nothing.
    def self.refusal(eventlet:, occurrence_start:, user:)
      series_scope = eventlet.event.recurring? ? "occurrence" : "series"
      for_choice(eventlet, occurrence_start, user, "all", series_scope).tap(&:permitted?)
    end

    def self.for_choice(eventlet, occurrence_start, user, calendar_scope, series_scope)
      new(eventlet: eventlet, current_user: user,
        params: {calendar_scope: calendar_scope, series_scope: series_scope,
                 occurrence_start: occurrence_start&.to_i})
    end
    private_class_method :for_choice

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
          case [calendar_scope, effective_series_scope]
          when %w[all series] then move_event
          when %w[all following] then move_following
          when %w[all occurrence] then move_occurrence
          when %w[this series] then move_eventlet
          when %w[this following] then move_following_eventlets
          when %w[this occurrence] then move_eventlet_occurrence
          end
        raise ActiveRecord::Rollback unless saved
        true
      end || false
    end

    # Whether this user may make this choice at all, before knowing where it's dropped. Leaves the
    # reasons in errors when not.
    def permitted?
      errors.clear
      return false unless eventlet_policy.update?
      CHOICE_CHECKS.each { |check| send(check) }
      errors.empty?
    end

    # "Following" from the series' first occurrence leaves nothing behind, so it's treated as moving
    # the whole series. See SeriesChoices.
    def effective_series_scope
      series_choices.effective_scope(series_scope)
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

    def series_choices
      @series_choices ||= SeriesChoices.new(event: event, occurrence_start: occurrence_start,
        occurrence_starts_at: occurrence&.starts_at)
    end

    def recurring_series_move?
      effective_series_scope == "series" && event.recurring?
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
      # :move rather than :update, which would edit the series from an occurrence (EventForm).
      form = EventForm.new(action: :move, current_user: current_user, event: event,
        params: {starts_at: start_shift.apply(event.starts_at).iso8601,
                 ends_at: end_shift.apply(event.ends_at).iso8601})
      unless form.save
        form.errors.each { |e| errors.add(e.attribute, e.message) }
        return false
      end
      move_dragged_override(dragged_override)
    end

    # Moves this and later occurrences on every calendar by the drag distance, leaving earlier ones
    # alone, by splitting off a new series from the dragged occurrence.
    def move_following
      # Loaded before the split, which moves these same records to the new series in place.
      dragged_override = existing_event_override
      SeriesSplitter.new(event).split_at(occurrence_start, start_shift: start_shift, end_shift: end_shift)
      move_dragged_override(dragged_override)
    end

    # An occurrence that was already moved on all calendars keeps its own time when the series moves,
    # so it needs the same shift to land where it was dropped.
    def move_dragged_override(override)
      return true unless override&.starts_at
      override.starts_at = start_shift.apply(override.starts_at)
      override.ends_at = end_shift.apply(override.ends_at)
      persist(override)
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
      shift_offsets(eventlet, override, override && dragged_override_offsets)
    end

    # Moves this and later occurrences on this calendar only. The series is split where it is, then
    # the new series' eventlet for this calendar gets the new offsets.
    def move_following_eventlets
      # Worked out before the split, which moves the override to the new series' eventlet in place,
      # after which it can no longer be found from this eventlet.
      override = dragged_eventlet_override
      override_offsets = override && dragged_override_offsets
      no_shift = WallClockShift.new(occurrence_start, occurrence_start)
      continuation = SeriesSplitter.new(event).split_at(occurrence_start, start_shift: no_shift,
        end_shift: no_shift)
      target = continuation.eventlets.detect { |e| e.calendar_id == eventlet.calendar_id }
      shift_offsets(target, override, override_offsets)
    end

    # Gives the eventlet this drag's new offsets. The dragged occurrence's own offsets on this
    # calendar replace the eventlet's, so they need the same change for it to land where it was dropped.
    def shift_offsets(target_eventlet, override, override_offsets)
      target_eventlet.start_offset, target_eventlet.end_offset = series_offsets
      return false unless persist(target_eventlet)
      return true unless override
      override.start_offset, override.end_offset = override_offsets
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

    # This eventlet's new offsets for a this-calendar series or following drag.
    def series_offsets
      [eventlet.start_offset + start_delta, eventlet.end_offset + end_delta]
    end

    # The dragged occurrence's own override offsets after a this-calendar series or following drag.
    # An offset the override doesn't set falls back to the eventlet's, which is already moving, so it
    # stays unset.
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
      errors.add(:ends_at, :before_start) if starts_at >= ends_at
    end

    # Every drag of a recurring event is measured from the dragged occurrence, so it has to be named
    # and still exist. A single-occurrence or following drag also needs the event to be recurring.
    def occurrence_resolvable
      return unless event.recurring? || series_scope != "series"
      validate_occurrence_in_series
      return if errors.any? || occurrence
      errors.add(:base, :occurrence_missing)
    end

    # A series' end date belongs to the event, not to each eventlet, so on an event with only one
    # calendar, "this calendar" and "all calendars" are the same thing. Deletion has the same rule.
    def scope_combination_allowed
      return unless calendar_scope == "this" && series_scope == "following"
      errors.add(:base, :one_calendar) if event.eventlets.size < 2
    end

    # Moving on all calendars changes the event on every calendar it's on, so the user has to be able
    # to edit all of them, not just the one they dragged on. EventsController checks the same thing for
    # the event form, and deletion does for its all-calendars choices.
    def restrict_all_calendars_to_editors
      return unless calendar_scope == "all" && event.eventlets.size > 1
      errors.add(:base, :other_calendar_not_editable) unless EventPolicy.new(current_user, event).update?
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
      errors.add(:base, :offsets_too_far_apart, hours: max / 1.hour)
    end

    # Mirrors EventForm#restrict_changes_in_past, but for the dragged occurrence rather than the
    # series as a whole. Meal events are exempt because they're maintained by the meal event handler
    # rather than by hand.
    def restrict_changes_in_past
      return if past_change_exempt?
      errors.add(:starts_at, :changed_after_start) if occurrence.starts_at.past?
    end

    def restrict_drop_in_past
      return if past_change_exempt?
      errors.add(:ends_at, :in_past) if ends_at&.past?
    end

    def past_change_exempt?
      occurrence.nil? || eventlet.meal? || eventlet_policy.privileged_change? || eventlet.recently_created?
    end

    # Moving every occurrence of a series that has started would move past ones too. See SeriesChoices.
    def restrict_series_moves_after_start
      return unless recurring_series_move?
      refusal = series_choices.refusal("series")
      errors.add(:base, refusal) if refusal
    end

    # "This and following" from an occurrence that has begun would move it. See SeriesChoices.
    def restrict_following_from_past
      return unless effective_series_scope == "following" && occurrence
      refusal = series_choices.refusal("following")
      errors.add(:base, refusal) if refusal
    end

    # A rule pinned to particular days or times (e.g. "every Tuesday") can't follow its start to a
    # slot the pattern excludes: the series would stay put and its overrides would no longer line up.
    def series_pattern_allows_move
      return if errors.any? || calendar_scope != "all" || !event.recurring?
      return if effective_series_scope == "occurrence"
      old_start = (effective_series_scope == "following") ? occurrence_start : event.starts_at
      new_start = start_shift.apply(old_start)
      # The UNTIL moves along with the start, so only the pattern itself is checked.
      rule = IceCube::Rule.from_hash(event.recurrence_rule).until(nil)
      return if IceCube::Schedule.new(new_start) { |s| s.add_recurrence_rule(rule) }.occurs_at?(new_start)
      errors.add(:base, :fixed_pattern)
    end

    # Overlap is checked at the eventlet level rather than the event level, since two eventlets on
    # the same calendar are what actually collide in the grid.
    def no_overlap
      return if errors.any? || calendar.allow_overlap?
      clashes = Eventlet.between(starts_at..ends_at)
        .where(calendar_id: eventlet.calendar_id)
        .where.not(id: eventlet.id)
      errors.add(:base, :overlap) if clashes.any?
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

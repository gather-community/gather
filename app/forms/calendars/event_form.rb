# frozen_string_literal: true

module Calendars
  # Creates and edits events, including repeating ones.
  #
  # Editing a repeating event (a "series edit") works from one of its occurrences, the one the user
  # opened. The form shows that occurrence's times and the series' repeat settings, and any change
  # applies from that occurrence on: the series is split there (SeriesSplitter), unless the opened one
  # is the first, when the whole series changes. Occurrences before it never change, as some may be
  # past, so nothing can be changed from an occurrence that has begun. A save that changes nothing
  # leaves the series as it is.
  #
  # A change of time is the move from the opened occurrence to the new times, the same as dragging it,
  # so the series' start is never re-anchored on the opened occurrence.
  class EventForm
    NAME_MAX_LENGTH = 24
    REPEAT_FIELDS = %i[repeat_frequency repeat_interval repeat_weekdays repeat_monthly_by repeat_ends
      repeat_ends_on repeat_count].freeze

    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include Rails.application.routes.url_helpers
    extend AttributeNormalizer::ClassMethods

    # These are persisted attributes that are persisted to the database.
    delegate :note, :name, :kind, :sponsor_id, :all_day, :creator_id, :group_id, to: :event

    # These are ephemeral attributes that are not persisted to the database.
    # origin_page tracks the page that the event was created from, so we can redirect back to it after creation.
    # guidelines_ok tracks whether the user has accepted the guidelines, and is used for validation only.
    attr_accessor :origin_page, :guidelines_ok

    alias :all_day? :all_day

    attr_reader :event, :pattern, :occurrence_start

    delegate :creator, to: :event
    delegate :frequency, :interval, :weekdays, :monthly_by, :ends, :ends_on, :count, to: :pattern,
      prefix: :repeat, allow_nil: true

    normalize_attributes :kind, :note

    validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
    validates :starts_at, :ends_at, presence: true
    validate :guidelines_accepted
    validate :start_before_end
    validate :restrict_changes_in_past
    validate :repeat_settings_valid
    validate :series_edit_allowed
    validate :no_overlap
    validate :apply_rules
    validate lambda { |r| meal&.event_handler&.validate_event(r.event) }

    class << self
      delegate :reflect_on_association, to: Event
    end

    def self.model_name
      Calendars::Event.model_name
    end

    # If not passing an id or event object, current_user and params.calendar_id are required,
    # and a new event will be initialized with default parameters.
    #
    # params is not required when instantiating for the purpose of #new and #edit.
    # params is also not required if passing an already-constructed event object.
    # params is a hash of parameters that will be used to initialize the event.
    # params can be a regular Hash or an ActionController::Parameters object.
    #
    # The :edit and :update actions edit a repeating event as a series (see the class comment), with
    # params[:occurrence_start] naming the occurrence it was opened from. Other callers that set an
    # event's times directly, such as a drag (EventletForm), use a different action.
    #
    # This method will filter permitted attributes based on the policy for the event.
    def initialize(action: nil, current_user: nil, event: nil, id: nil, params: nil)
      @current_user = current_user
      @action = action

      # If we need to build an event object, we set the calendar on it so we can pass it to the policy object.
      if id.nil? && event.nil?
        calendar_id = params.delete(:calendar_id)
        raise "current_user and params[:calendar_id] are required when not passing an event" if current_user.nil? || calendar_id.nil?

        @event = Event.new(creator: current_user)
        @event.calendar = Calendar.find(calendar_id)
      elsif event.present?
        @event = event
      else
        @event = Event.find(id)
      end

      @series_edit = @event.persisted? && @event.recurring? && %i[edit update].include?(@action)
      extract_series_params(params)
      parse_starts_and_ends_at(params)
      set_default_starts_and_ends_at(params) if @action == :new

      if params.present?
        self.origin_page = params.delete(:origin_page)
        self.guidelines_ok = params.delete(:guidelines_ok)
        if @current_user
          permitted_attributes = event_policy.permitted_attributes(group_id: params[:group_id])
          unless params.is_a?(ActionController::Parameters)
            params = ActionController::Parameters.new(params)
          end
          @event.assign_attributes(params.permit(permitted_attributes))
        end
      end
    end

    def valid?(*args)
      normalize

      super(*args)
    end

    def save
      return false unless valid?
      return save_series_edit if series_edit?
      if pattern && recurrence_offered?
        @event.recurrence_rule = pattern.to_rule_hash(starts_at, all_day: all_day?)
      end
      @event.save
    end

    def guidelines_ok?
      guidelines_ok == "1"
    end

    def url
      if %i[new create].include?(@action)
        calendars_events_path
      else
        calendars_event_path(@event)
      end
    end

    # Where the form-refresh controller sends the form to re-render the parts that depend on it.
    def refresh_url
      persisted? ? form_refresh_calendars_event_path(@event) : form_refresh_calendars_events_path
    end

    def series_edit?
      @series_edit
    end

    # The start and end shown in the form. In a series edit, they're the opened occurrence's, as
    # scheduled, so the change is measured from it.
    def starts_at
      series_edit? ? (@form_starts_at || occurrence_start) : event.starts_at
    end

    def ends_at
      series_edit? ? (@form_ends_at || occurrence_start + series_duration) : event.ends_at
    end

    # Whether the form offers repeat settings: not for meal events, and only on calendars that allow
    # repeating events (Calendar#allows_recurring_events?).
    def recurrence_offered?
      !event.meal? && repeat_calendars.all?(&:allows_recurring_events?)
    end

    # Why repeat settings aren't offered here, for the note shown in their place, or nil if they are.
    def recurrence_blockers
      return [] if event.meal?
      repeat_calendars.flat_map(&:recurrence_blockers).uniq
    end

    # Whether the repeat settings can be edited: a series made elsewhere may repeat in a way the form
    # can't show (RecurrencePattern.from_rule), and is then kept as it is.
    def pattern_editable?
      !pattern.nil?
    end

    # Whether the form shows repeat fields to fill in, rather than a note in their place.
    def repeat_settings_editable?
      return false if event.meal?
      series_edit? ? pattern_editable? : recurrence_offered?
    end

    # Whether a repeat detail field applies to the current settings, as named in its data-repeat-show.
    # The calendars--event-form controller makes the same decision as the settings change.
    def repeat_detail_applies?(show)
      repeats = repeat_frequency.present?
      case show
      when "repeats" then repeats
      when "weekly", "monthly" then repeat_frequency == show
      when "on_date", "after_count" then repeats && repeat_ends == show
      end
    end

    # The opened occurrence on the event's own calendar, with any change to it applied. Nil if it
    # doesn't exist, e.g. it was deleted in another tab.
    def opened_occurrence
      return @opened_occurrence if defined?(@opened_occurrence)
      @opened_occurrence = OccurrenceResolver.new(primary_eventlet, occurrence_start.to_i).resolve
    end

    # The event's eventlet on its own calendar.
    def primary_eventlet
      event.eventlets.detect { |e| e.calendar_id == event.calendar_id } || event.eventlets.first
    end

    # Whether this series edit changes anything: the times, the repeat settings, or the event's fields.
    def series_changed?
      return false unless series_edit?
      times_changed? || days_changed? || ends_changed? || field_changes.any?
    end

    # Whether the form can change anything. In a series edit, not from an occurrence that has begun,
    # since the change would apply to it.
    def editable?
      return true unless series_edit?
      opened_occurrence.present? && series_choices.refusal(series_scope).nil?
    end

    # Whether the start can be changed. Besides the above, an event that has begun keeps its start,
    # except for an admin, or its creator within the hour to fix a mistake.
    def start_editable?
      editable? && !start_locked?
    end

    # Whether changes apply only from the opened occurrence on, leaving earlier ones as they are,
    # rather than to the whole series from its first occurrence.
    def applies_from_opened?
      series_edit? && series_scope == "following"
    end

    # The series' first occurrence that hasn't begun and wasn't deleted, which the note at the top of
    # the form suggests editing from. Nil if there's none.
    def first_upcoming_occurrence
      return @first_upcoming_occurrence if defined?(@first_upcoming_occurrence)
      deleted = event.event_overrides.select(&:deleted?).map(&:occurrence_start)
      @first_upcoming_occurrence = event.schedule.next_occurrences(deleted.size + 1, Time.current)
        .map(&:to_time).find { |t| deleted.exclude?(t) }
    end

    # The weekdays shown ticked: those chosen, and always the start's, which can't be unticked.
    def repeat_weekdays_shown
      return [] unless starts_at
      pattern ? pattern.weekdays_for(starts_at) : [starts_at.wday]
    end

    # The monthly choices the start date allows (RecurrencePattern.monthly_by_options), and the one shown
    # chosen: the closest to the current choice, which may not suit a start date that just changed.
    def repeat_monthly_by_options
      starts_at ? RecurrencePattern.monthly_by_options(starts_at) : RecurrencePattern::MONTHLY_BY.take(1)
    end

    def repeat_monthly_by_shown
      return repeat_monthly_by unless starts_at
      RecurrencePattern.closest_monthly_by(repeat_monthly_by || "day_of_month", starts_at)
    end

    private

    attr_reader :current_user

    delegate(
      :calendar_allows_overlap?,
      :calendar_id,
      :calendar,
      :id,
      :meal,
      :meal?,
      :new_record?,
      :persisted?,
      :recently_created?,
      :rule_set,
      :starts_at_was,
      :will_save_change_to_starts_at?,
      :will_save_change_to_ends_at?,
      to: :event
    )

    # This policy is needed for two things:
    # 1. To determine which attributes are permitted (only needed when params are submitted)
    # 2. For certain validation rules that need to check the policy. As of this writing,
    #    this was only to check the privileged_change? permission for editing an event in the past.
    def event_policy
      @event_policy ||= EventPolicy.new(@current_user, @event)
    end

    # Repeat settings, and for a series edit the occurrence and the choice of occurrences, aren't event
    # attributes, so they're taken out before the rest are assigned.
    def extract_series_params(params)
      params ||= {}
      sent = extract_pattern(params)
      return unless series_edit?

      occurrence_param = params.delete(:occurrence_start)
      @occurrence_start = occurrence_param.present? ? Time.zone.at(occurrence_param.to_i) : @event.starts_at
      # Settings that weren't sent are unchanged, as the form would send them: without the opened
      # occurrence's weekday, whose checkbox follows the start (see #normalize).
      @pattern.weekdays = @pattern.weekdays - [@occurrence_start.wday] if !sent && @pattern
    end

    # The repeat settings sent, or the event's own if none were. Returns whether any were sent.
    def extract_pattern(params)
      @original_pattern = RecurrencePattern.from_rule(@event.recurrence_rule)
      repeat_params = REPEAT_FIELDS.index_with { |field| params.delete(field) }
      sent = repeat_params.values.any?(&:present?) && !@event.meal?
      # A copy, as #normalize changes it and the original is compared against (#days_changed?).
      @pattern =
        if sent
          RecurrencePattern.new(**repeat_params.transform_keys { |k| k.to_s.delete_prefix("repeat_").to_sym })
        else
          @original_pattern&.dup
        end
      sent
    end

    def parse_starts_and_ends_at(params)
      if params.present?
        # Parse the starts_at and ends_at from the params if they are present.
        # We delete them because we don't want to call super with them
        # because then they would overwrite the values we may set in set_default_starts_and_ends_at.
        starts_at_param = params.delete(:starts_at)
        ends_at_param = params.delete(:ends_at)
        starts = Time.zone.parse(starts_at_param) if starts_at_param.present?
        ends = Time.zone.parse(ends_at_param) if ends_at_param.present?
        if series_edit?
          @form_starts_at = starts
          @form_ends_at = ends
        else
          @event.starts_at = starts if starts
          @event.ends_at = ends if ends
        end
      end
    end

    def set_default_starts_and_ends_at(params)
      # If no initial starts_at and ends_at were provided, set the default values.
      @event.starts_at ||= Time.current.midnight + 1.week + 17.hours
      @event.ends_at ||= Time.current.midnight + 1.week + 18.hours

      # If the rule set has a fixed start/end time, use it.
      # This should override the default values if they are present.
      rule_set = @event.rule_set
      if fst = rule_set.fixed_start_time
        @event.starts_at = starts_at.change(hour: fst.hour, min: fst.min)
      end
      if fet = rule_set.fixed_end_time
        @event.ends_at = ends_at.change(hour: fet.hour, min: fet.min)
      end
      if fst && fet && starts_at >= ends_at
        @event.ends_at += 1.day
      end
    end

    # Brings the times and repeat settings into the shape they're saved in: an all-day event's times
    # cover whole days, and a weekly series always includes the start's weekday. Called before
    # validating.
    def normalize
      @event.all_day = false if rule_set.timed_events_only?
      if all_day? && starts_at && ends_at
        assign_times(starts_at.midnight,
          ends_at.midnight + 1.day - 1.second)
      end
      # The start's weekday checkbox is disabled, so it isn't sent. It's always included, even if the
      # page hadn't caught up with a change to the start.
      pattern.weekdays = pattern.weekdays_for(starts_at) if pattern&.frequency == "weekly" && starts_at
    end

    def assign_times(starts, ends)
      if series_edit?
        @form_starts_at = starts
        @form_ends_at = ends
      else
        @event.starts_at = starts
        @event.ends_at = ends
      end
    end

    # === Series edits ===

    def series_choices
      @series_choices ||= SeriesChoices.new(event: event, occurrence_start: occurrence_start,
        occurrence_starts_at: opened_occurrence&.starts_at)
    end

    # "following" from a later occurrence, or "series" from the first, where they mean the same.
    def series_scope
      series_choices.effective_scope("following")
    end

    def times_changed?
      starts_at != occurrence_start || ends_at != occurrence_start + series_duration
    end

    def start_locked?
      return false if !persisted? || series_edit? || event.meal? || recently_created?
      return false if event_policy.privileged_change?
      event.starts_at_in_database&.past?
    end

    def series_duration
      (event.ends_at_in_database || event.ends_at) - (event.starts_at_in_database || event.starts_at)
    end

    # The move the change makes to the opened occurrence, as wall-clock shifts of its start and end.
    def start_shift
      WallClockShift.new(occurrence_start, starts_at)
    end

    def end_shift
      WallClockShift.new(occurrence_start + series_duration, ends_at)
    end

    # Occurrences that have been moved or deleted in the part of the series this edit changes.
    def changed_occurrences
      overrides = event.event_overrides.to_a
      return overrides unless series_scope == "following"
      overrides.select { |o| o.occurrence_start >= occurrence_start }
    end

    def days_changed?
      return false unless @original_pattern && pattern
      @original_pattern.days_key(occurrence_start) != pattern.days_key(starts_at)
    end

    def ends_changed?
      return false unless @original_pattern && pattern
      @original_pattern.ends_key != pattern.ends_key
    end

    def save_series_edit
      return true unless series_changed?
      ActiveRecord::Base.transaction do
        if series_scope == "following"
          save_following
        else
          save_whole_series
        end
      end
      true
    end

    def save_whole_series
      shift = start_shift
      event.starts_at = shift.apply(event.starts_at)
      event.ends_at = end_shift.apply(event.ends_at)
      if pattern
        rule = pattern.to_rule_hash(event.starts_at, all_day: all_day?)
        drop_overrides_past_end(event.event_overrides, rule, event.starts_at, shift)
        event.recurrence_rule = rule
      end
      clear_offsets(event.eventlets) if event.will_save_change_to_all_day?
      event.save!
    end

    # The original keeps everything up to the opened occurrence; the new series starting there gets
    # the changes. Its rule only changes if the repeat settings did, since otherwise the original's,
    # picked up from the cut (SeriesSplitter#continuation_rule), is already right.
    def save_following
      changes = field_changes
      event.restore_attributes
      rule = pattern.to_rule_hash(starts_at, all_day: changes.fetch("all_day", all_day?)) if pattern &&
        (days_changed? || ends_changed?)
      split_off = SeriesSplitter.new(event).split_at(occurrence_start, start_shift: start_shift,
        end_shift: end_shift, rule: rule)
      split_off.assign_attributes(changes)
      clear_offsets(split_off.eventlets) if changes.key?("all_day")
      split_off.save!
    end

    # The event's fields the form changed, as {attribute => new value}. A blank field sent for one
    # that's empty (e.g. "" for no note) isn't a change.
    def field_changes
      event.changes.reject { |_attr, (was, now)| was.blank? && now.blank? }.transform_values(&:last)
    end

    # Shortening the end leaves changes to occurrences that no longer exist. They're removed, the same
    # as "delete this and following" does (SeriesSplitter#truncate_before).
    def drop_overrides_past_end(overrides, rule, new_start, shift)
      schedule = IceCube::Schedule.new(new_start) { |s| s.add_recurrence_rule(IceCube::Rule.from_hash(rule)) }
      return unless schedule.terminating?
      last = schedule.last.to_time
      overrides.destroy(overrides.select { |o| shift.apply(o.occurrence_start) > last })
    end

    # An all-day event can't start earlier or later on one calendar than another.
    def clear_offsets(eventlets)
      eventlets.each do |eventlet|
        eventlet.start_offset = 0
        eventlet.end_offset = 0
      end
    end

    # === Validations ===

    def guidelines_accepted
      return unless new_record? && calendar.guidelines? && !guidelines_ok?
      errors.add(:guidelines, :not_accepted)
    end

    # The :guidelines field is only a checkbox wrapper, but ActiveModel reads the attribute when it
    # builds the error message above.
    def guidelines
      nil
    end

    def start_before_end
      return unless starts_at.present? && ends_at.present? && starts_at >= ends_at
      errors.add(:ends_at, :before_start)
    end

    def no_overlap
      return if calendar_allows_overlap? || starts_at.blank? || ends_at.blank?
      query = Event.between(starts_at..ends_at)
      query = query.where(calendar_id: calendar_id)
      query = query.where("id != #{id}") if persisted?
      errors.add(:base, :overlap) if query.any?
    end

    # In a series edit, the rules are checked against the edited occurrence's new times.
    def apply_rules
      return if errors.any?
      target = event
      if series_edit?
        target = event.dup.tap { |e| e.assign_attributes(starts_at: starts_at, ends_at: ends_at) }
      end
      rule_set.errors(target).each { |e| errors.add(*e) }
    end

    # Only admins can move an event into the past. An event's creator can change its start after it
    # begins within the hour of creating it, to fix a mistake, but not move it into the past. Meal events
    # are exempt, as the meal event handler creates and updates them.
    def restrict_changes_in_past
      return if !persisted? || event.meal? || event_policy.privileged_change?
      if series_edit?
        errors.add(:ends_at, :in_past) if times_changed? && ends_at&.past?
        return
      end
      errors.add(:starts_at, :changed_after_start) if start_locked? && will_save_change_to_starts_at?
      if will_save_change_to_ends_at? && ends_at&.past? # rubocop:disable Style/GuardClause # || structure
        errors.add(:ends_at, :in_past)
      end
    end

    def repeat_settings_valid
      return unless pattern&.recurring?
      return errors.add(:repeat_frequency, :not_offered) if !series_edit? && !recurrence_offered?
      unless pattern.valid?
        pattern.errors.each { |e| errors.add(:"repeat_#{e.attribute}", e.message) }
        return
      end
      repeat_settings_fit_times unless starts_at.blank? || ends_at.blank?
    end

    def repeat_settings_fit_times
      if pattern.ends == "on_date" && pattern.ends_on < starts_at.to_date
        errors.add(:repeat_ends_on, :before_start)
      elsif ends_at - starts_at > pattern.min_gap(starts_at)
        errors.add(:base, :longer_than_repeat)
      elsif pattern.frequency == "monthly" &&
          RecurrencePattern.monthly_by_options(starts_at).exclude?(pattern.monthly_by)
        # E.g. "the 4th Tuesday" after the start moved to a fifth Tuesday. The page offers only what the
        # start allows, but may not have caught up with a change to it.
        errors.add(:repeat_monthly_by, :not_on_start_date)
      end
    end

    def series_edit_allowed
      return unless series_edit?
      return errors.add(:base, :occurrence_missing) unless opened_occurrence
      return errors.add(:repeat_frequency, :stop_repeating) if pattern && !pattern.recurring?
      return unless series_changed?
      # The page disables the form then, but may not have caught up with the time passing.
      return errors.add(:base, :changed_from_started) unless editable?
      if series_scope == "following"
        refusal = series_choices.following_move_refusal(starts_at)
        return errors.add(:base, refusal) if refusal
      end
      return if changed_occurrences.empty?
      if days_changed?
        errors.add(:base, :pattern_change_with_changes, count: changed_occurrences.size)
      elsif event.will_save_change_to_all_day?
        errors.add(:base, :all_day_change_with_changes, count: changed_occurrences.size)
      end
    end

    # The calendars a repeating event would be on: those it's on, or for a new one, its calendar.
    def repeat_calendars
      event.eventlets.any? ? event.eventlets.map(&:calendar) : [event.calendar].compact
    end
  end
end

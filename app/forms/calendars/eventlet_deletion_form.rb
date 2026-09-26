# frozen_string_literal: true

module Calendars
  # Deletes all or part of an event, starting from one eventlet (and, for a recurring series, one
  # occurrence of it). Like EventletForm, a deletion carries two independent scope choices:
  #
  #                  | series                | following              | occurrence
  #   ---------------|-----------------------|------------------------|-------------------------------
  #   all calendars  | destroy the Event     | end the series before  | EventOverride deleted
  #                  |                       | this occurrence        |
  #   this calendar  | destroy this Eventlet | (not offered)          | EventletOverride deleted
  #
  # "This and following" has no this-calendar form because a series' end date belongs to the event,
  # not to each eventlet.
  #
  # Permission depends on which record is being deleted, so rather than a policy of its own, the
  # form names the records (authorization_targets) whose existing destroy? policies must all pass.
  class EventletDeletionForm
    CALENDAR_SCOPES = EventletForm::CALENDAR_SCOPES
    SERIES_SCOPES = %w[occurrence following series].freeze

    include ActiveModel::Conversion
    include ActiveModel::Validations
    include OccurrenceOverrides

    attr_reader :eventlet, :occurrence_start, :calendar_scope, :series_scope

    delegate :event, :calendar, to: :eventlet

    validates :calendar_scope, inclusion: {in: CALENDAR_SCOPES}
    validates :series_scope, inclusion: {in: SERIES_SCOPES}
    validate :scope_combination_allowed
    validate :occurrence_valid

    def self.model_name
      Calendars::Eventlet.model_name
    end

    # The scope combinations the given user may choose for this eventlet/occurrence, as
    # {"this" => [series scopes...], "all" => [series scopes...]}. Drives the delete modal's options.
    def self.allowed_choices(eventlet:, occurrence_start:, user:)
      CALENDAR_SCOPES.index_with do |calendar_scope|
        SERIES_SCOPES.select do |series_scope|
          params = {calendar_scope: calendar_scope, series_scope: series_scope,
                    occurrence_start: occurrence_start&.to_i}
          form = new(eventlet: eventlet, current_user: user, params: params)
          # "Following" from the first occurrence is the same as the whole series, so don't offer both.
          form.series_scope == form.effective_series_scope && form.permitted_for?(user)
        end
      end
    end

    def initialize(eventlet:, current_user: nil, params: {})
      @eventlet = eventlet
      if params.respond_to?(:permit)
        params = params.permit(EventletPolicy.new(current_user, eventlet).permitted_attributes_for_destroy)
      end
      @occurrence_start = parse_unix(params[:occurrence_start])
      @calendar_scope = params[:calendar_scope].presence || "all"
      @series_scope = params[:series_scope].presence || "series"
    end

    def save
      return false unless valid?

      ActiveRecord::Base.transaction do
        case [calendar_scope, effective_series_scope]
        when %w[all series] then event.destroy!
        when %w[all occurrence] then delete_occurrence
        when %w[all following] then end_series_before_occurrence
        when %w[this series] then remove_eventlet
        when %w[this occurrence] then delete_eventlet_occurrence
        end
      end
      true
    end

    # The records whose destroy? policy must pass for this deletion. Per-occurrence permission falls
    # out of this: Eventlet#future? on a resolved occurrence uses that occurrence's own time. For
    # "following", the occurrence at the cutoff is the earliest one affected. Empty when the
    # combination is unknown or the occurrence can't be resolved (e.g. it was already deleted).
    def authorization_targets
      case [calendar_scope, effective_series_scope]
      when %w[all series] then [event]
      when %w[this series] then [eventlet]
      when %w[this occurrence] then [occurrence].compact
      when %w[all occurrence], %w[all following] then occurrences_on_all_calendars
      else []
      end
    end

    def target_missing?
      authorization_targets.empty?
    end

    def permitted_for?(user)
      valid? && authorization_targets.any? &&
        authorization_targets.all? { |record| Pundit.policy!(user, record).destroy? }
    end

    # "Following" from the series' first occurrence leaves nothing behind, so it's treated as a
    # whole-series delete.
    def effective_series_scope
      return series_scope unless series_scope == "following" && event.recurring? && occurrence_start
      event.schedule.previous_occurrence(occurrence_start) ? "following" : "series"
    end

    # Names the flash message for what was deleted.
    def result_key
      case [calendar_scope, effective_series_scope]
      when %w[all series] then event.recurring? ? "series" : "event"
      when %w[this series] then "calendar_series"
      when %w[this occurrence] then "calendar_occurrence"
      else effective_series_scope
      end
    end

    # The date to return the user to on the calendar after deleting.
    def starts_at
      occurrence_start || eventlet.starts_at
    end

    def persisted?
      true
    end

    private

    # === Occurrence lookup ===

    # This eventlet's occurrence, resolved with any overrides. A non-recurring event's only
    # "occurrence" is the eventlet itself. Nil for a recurring event with no occurrence_start: we
    # never fall back to the series' first occurrence (as the show page does) when deleting.
    def occurrence
      return @occurrence if defined?(@occurrence)
      @occurrence =
        if !event.recurring?
          eventlet
        elsif occurrence_start
          OccurrenceResolver.new(eventlet, occurrence_start.to_i).resolve
        end
    end

    # The same occurrence on each of the event's calendars, skipping any already deleted there.
    def occurrences_on_all_calendars
      return [] unless occurrence_start
      event.eventlets.filter_map { |e| OccurrenceResolver.new(e, occurrence_start.to_i).resolve }
    end

    # === Write paths ===

    # Deletes one occurrence on every calendar. Any per-calendar changes to it are moot once it's gone.
    def delete_occurrence
      override = find_or_initialize_event_override
      override.eventlet_overrides.destroy_all if override.persisted?
      override.update!(deleted: true, starts_at: nil, ends_at: nil)
    end

    # Ends the series with the occurrence just before this one, and drops overrides for occurrences
    # that no longer exist. UNTIL is inclusive, so setting it to the last kept occurrence is exact.
    def end_series_before_occurrence
      last_kept = event.schedule.previous_occurrence(occurrence_start)
      rule = IceCube::Rule.from_hash(event.recurrence_rule)
      rule.count(nil)
      # previous_occurrence returns an IceCube::Occurrence, which ice_cube can't serialize. to_time
      # unwraps it to a zoned time, which serializes as {time:, zone:} and round-trips through JSONB.
      rule.until(last_kept.to_time)
      event.event_overrides.where(occurrence_start: occurrence_start..).destroy_all
      event.update!(recurrence_rule: rule.to_hash)
    end

    # Removes the event from this calendar, or deletes it outright if this is its last calendar.
    def remove_eventlet
      return event.destroy! if event.eventlets.size <= 1

      eventlet.destroy!
      event.eventlets.reset
      # The event's own calendar determines its community for policy checks, so it must stay one
      # the event still appears on.
      event.update!(calendar: event.eventlets.first.calendar) if event.calendar_id == eventlet.calendar_id
    end

    # Deletes one occurrence on this calendar only. The anchor EventOverride carries no change of
    # its own; it just holds the occurrence_start identity the EventletOverride hangs off.
    def delete_eventlet_occurrence
      anchor = find_or_initialize_event_override
      anchor.save! if anchor.new_record?
      find_or_initialize_eventlet_override(anchor)
        .update!(deleted: true, start_offset: nil, end_offset: nil)
    end

    # === Validations ===

    def scope_combination_allowed
      return if errors.any?
      if calendar_scope == "this" && series_scope == "following"
        errors.add(:base, "“This and following” can only be deleted from all calendars")
      elsif calendar_scope == "this" && event.eventlets.size < 2
        errors.add(:base, "This event is only on one calendar")
      end
    end

    def occurrence_valid
      return if errors.any?
      validate_occurrence_in_series if %w[occurrence following].include?(series_scope)
    end
  end
end

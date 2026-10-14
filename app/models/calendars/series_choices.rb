# frozen_string_literal: true

module Calendars
  # The rules for changing several occurrences of a series at once. Shared by dragging (EventletForm)
  # and editing (EventForm), so the two can't drift apart.
  #
  # - "series" (All occurrences) would change past occurrences too once the series has started, so it's
  #   only allowed before then, or while the series was created within the hour. That holds for
  #   everyone, admins included: past occurrences never change as a side effect. "Started" goes by the
  #   schedule's first slot, so a series whose first occurrence was deleted or moved later still counts.
  # - "following" (This and following) changes this occurrence and later ones, so this occurrence must
  #   not have begun, judged by where it was before the change, not where it's moved to.
  # - "following" from the series' first occurrence leaves nothing behind, so it means "series".
  # - "following" can't move this occurrence to or before the last one it leaves behind, or the two
  #   parts of the series would overlap (#following_move_refusal).
  class SeriesChoices
    SCOPES = %w[following series].freeze

    attr_reader :event, :occurrence_start, :occurrence_starts_at

    # occurrence_start identifies the occurrence (its scheduled start); occurrence_starts_at is where it
    # currently is, after any change to it. The latter is nil if the occurrence no longer exists.
    def initialize(event:, occurrence_start:, occurrence_starts_at:)
      @event = event
      @occurrence_start = occurrence_start
      @occurrence_starts_at = occurrence_starts_at
    end

    def effective_scope(scope)
      return scope unless scope == "following" && event.recurring? && occurrence_start
      event.schedule.previous_occurrence(occurrence_start) ? "following" : "series"
    end

    # The error key refusing the scope, or nil if it's allowed.
    def refusal(scope)
      case effective_scope(scope)
      when "series" then :series_started if event.recurring? && started? && !event.recently_created?
      when "following" then :following_from_past if occurrence_starts_at&.past?
      end
    end

    # The error key and message details refusing a "following" move of this occurrence to new_start,
    # or nil if it's allowed. The original series is cut so its last scheduled occurrence is the one
    # before this, so the moved part has to start after that.
    def following_move_refusal(new_start)
      kept = event.schedule.previous_occurrence(occurrence_start)&.to_time
      return nil if kept.nil? || new_start > kept
      [:moved_before_kept, {date: I18n.l(kept.to_date, format: :long)}]
    end

    # The multi-occurrence scopes that are allowed, leaving out "following" where it means "series".
    def allowed_scopes
      SCOPES.select { |scope| effective_scope(scope) == scope && refusal(scope).nil? }
    end

    private

    def started?
      # The value in the database, so a change being made to the start doesn't count.
      (event.starts_at_in_database || event.starts_at).past?
    end
  end
end

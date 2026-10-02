# frozen_string_literal: true

module Calendars
  # Shared by the forms that act on a single occurrence of a recurring series (EventletForm for
  # drag-to-move, EventletDeletionForm for deletion). Includers must provide `eventlet`, `event`,
  # `occurrence_start`, and `errors`.
  module OccurrenceOverrides
    extend ActiveSupport::Concern

    private

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

    # EventletOverride requires a parent EventOverride, which acts as an anchor holding the
    # occurrence_start identity.
    def find_or_initialize_eventlet_override(anchor)
      anchor.eventlet_overrides.detect { |o| o.eventlet_id == eventlet.id } ||
        anchor.eventlet_overrides.build(eventlet: eventlet)
    end

    def validate_occurrence_in_series
      if occurrence_start.blank?
        errors.add(:occurrence_start, "is required to change a single occurrence")
      elsif !event.recurring?
        errors.add(:base, "This event is not part of a series")
      elsif !event.schedule.occurs_at?(occurrence_start)
        errors.add(:occurrence_start, "is not a valid occurrence in this series")
      end
    end

    def parse_unix(value)
      return nil if value.blank?
      Time.zone.at(value.to_i)
    end
  end
end

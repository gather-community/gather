# frozen_string_literal: true

module Calendars
  # Represents one calendar row in the multi-event form.
  # Not persisted directly — maps to/from a Calendars::Eventlet on save.
  # The id field carries the associated Eventlet's ID when editing an existing event.
  class CalendarSlot
    include ActiveModel::Model

    attr_accessor :id, :calendar_id, :customize_times, :starts_at, :ends_at, :_destroy

    def marked_for_destruction? = _destroy.to_s == "1"
    def new_record? = id.blank?
    def persisted? = id.present?
    def customize_times? = customize_times.to_s == "1"

    def calendar
      @calendar ||= Calendars::Calendar.find_by(id: calendar_id)
    end

    def effective_starts_at(main_starts_at)
      customize_times? ? starts_at : main_starts_at
    end

    def effective_ends_at(main_ends_at)
      customize_times? ? ends_at : main_ends_at
    end
  end
end

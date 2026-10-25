# frozen_string_literal: true

module Calendars
  # Returns the user to the calendar view they came from (combined or single-calendar), on the date
  # of the event they just acted on.
  module EventContextRedirectable
    extend ActiveSupport::Concern

    private

    def redirect_to_event_in_context(starts_at:, calendar:, origin_page:)
      params = {date: starts_at&.to_fs(:no_time)}
      if origin_page == "combined"
        redirect_to(calendars_events_path(params))
      else
        redirect_to(calendar_events_path(calendar, params))
      end
    end
  end
end

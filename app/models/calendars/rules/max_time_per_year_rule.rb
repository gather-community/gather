# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting time reserved per year. Abstract class.
    class MaxTimePerYearRule < Rule
      def check(event)
        # If there is no creator, which is allowed on meal events, we can't calcuate time used.
        return true if event.creator.nil?

        booked = booked_time_for_year(event, unit)
        if booked + event.send(unit) > value
          msg = I18n.t("calendars/protocol.exceeded_time",
            kind_calendar: kind_calendar_str, max: interval(value), booked: interval(booked)).gsub("  ", " ")
          [:base, msg]
        else
          true
        end
      end

      private

      # Gets the amount of time that the given event's creator household has booked
      # on the current rule's calendars in the event's year, in the given unit (:hours or :minutes).
      # The number of days is rounded up for each event.
      # i.e., a 1-hour event and a 10-hour event both counts as 1 day, while a 36-hour event
      # counts as 2 days.
      def booked_time_for_year(event, unit)
        year = event.starts_at.year
        Event
          .where.not(id: event.id)
          .where(calendars.present? ? {calendar: calendars} : nil)
          .where(kinds.present? ? {kind: kinds} : nil)
          .where(creator: event.household_users)
          .where(starts_at: Time.zone.local(year)...Time.zone.local(year + 1))
          .to_a.sum(&unit)
      end

      def kind_calendar_str
        kind_str = (kinds || []).join("/").presence
        calendar_str = (calendars&.map(&:name) || []).join("/").presence
        joined = [kind_str, calendar_str].compact.join(" ")
        joined.blank? ? "" : "#{joined} "
      end
    end
  end
end

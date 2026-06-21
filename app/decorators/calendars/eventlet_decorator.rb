# frozen_string_literal: true

module Calendars
  class EventletDecorator < ApplicationDecorator
    include CalendarTimespanFormatting

    delegate_all

    # The real, persisted series event. It carries the recurrence_rule and a real id, whereas a
    # recurring occurrence's own `event` is a transient, non-recurring display copy. For a
    # non-recurring eventlet there is no linkable, so the eventlet's own event is the real one.
    def series_event
      object.linkable.is_a?(Calendars::Eventlet) ? object.linkable.event : object.event
    end

    def location_name
      calendar.decorate.name
    end

    # Human-readable recurrence pattern, e.g. "Weekly on Mondays at 6:00pm until Aug 31 2026".
    # Nil when not recurring.
    #
    # We start from IceCube's `to_s` (which handles interval, explicit weekdays, nth-weekday, and
    # day-of-month) but rebuild two things ourselves: (1) the frequency/day part is enriched with the
    # weekday/day-of-month/month-day implied by the anchor for "bare" rules (a plain weekly rule just
    # says "Weekly"), and (2) the trailing "until <date>"/"N times" clause is stripped and replaced
    # with our own I18n.l-formatted end date, so both until-rules and count rules read consistently in
    # Gather's date format. The time is included because for a rescheduled occurrence the Date/Time row
    # shows the moved time, not the series time.
    def recurrence_description
      return nil unless series_event.recurring?
      rule = series_event.schedule.rrules.first
      base = shorten_day_of_month(strip_end_clause(rule.to_s))
      [base, anchor_day_phrase(rule), time_phrase, end_clause].reject(&:blank?).join(" ")
    end

    private

    # IceCube spells a day-of-month rule as "on the 15th day of the month"; shorten it to "on the 15th"
    # so explicit and anchor-inferred monthly rules read consistently. "the last day of the month"
    # (no numeric ordinal) is intentionally left as-is.
    def shorten_day_of_month(text)
      text.gsub(/(\d+(?:st|nd|rd|th)) days? of the month/, '\1')
    end

    # Drops IceCube's trailing "until <date>" / "<N> times"; we rebuild the end clause in #end_clause.
    def strip_end_clause(text)
      text.sub(/ until .+\z| \d+ times\z/, "")
    end

    # "until Aug 31 2026" for both explicit-until and count-limited rules, from the precomputed
    # recurrence_end_date (the until date, or the date of the last occurrence for count rules).
    def end_clause
      return "" unless series_event.recurrence_end_date
      "until #{I18n.l(series_event.recurrence_end_date, format: :default)}"
    end

    # The weekday (weekly) or day-of-month (monthly) implied by the anchor, but only when the rule
    # doesn't already state it. Empty string when nothing needs adding.
    def anchor_day_phrase(rule)
      h = rule.to_hash
      validations = h[:validations] || {}
      case h[:rule_type]
      when "IceCube::WeeklyRule"
        return "" if validations[:day].present?
        "on #{series_event.starts_at.strftime("%A")}s"
      when "IceCube::MonthlyRule"
        return "" if validations[:day_of_week].present? || validations[:day_of_month].present?
        "on the #{series_event.starts_at.day.ordinalize}"
      when "IceCube::YearlyRule"
        return "" if validations[:month_of_year].present? || validations[:day_of_year].present?
        "on #{I18n.l(series_event.starts_at.to_date, format: :month_day)}"
      else
        ""
      end
    end

    def time_phrase
      return "" if all_day?
      # :time_only space-pads single-digit hours (" 6:00pm"); strip so we don't double the space.
      "at #{I18n.l(series_event.starts_at, format: :time_only).strip}"
    end
  end
end

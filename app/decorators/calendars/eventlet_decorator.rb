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

    # The persisted eventlet behind this one. For a recurring occurrence that's its linkable; a
    # non-recurring eventlet is its own base.
    def base_eventlet
      object.linkable.is_a?(Calendars::Eventlet) ? object.linkable : object
    end

    def location_name
      calendar.decorate.name
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(series_event, :edit, icon: "pencil",
          path: h.edit_calendars_event_path(series_event, url_params)),
        delete_action_link
      )
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

    # A plain event on one calendar keeps the simple confirm-and-delete. Otherwise the user has to
    # choose what to delete (which calendars, which occurrences), which the
    # calendars--eventlet-delete Stimulus controller asks in a modal before submitting.
    def delete_action_link
      return series_event.decorate.delete_action_link unless scoped_delete?

      choices = EventletDeletionForm.allowed_choices(eventlet: base_eventlet,
        occurrence_start: object.occurrence_start, user: h.current_user)
      ActionLink.new(base_eventlet, :destroy, icon: "trash",
        path: h.calendars_eventlet_path(base_eventlet, url_params),
        # Passed explicitly: the default check would be the base eventlet's destroy?, which is the
        # whole-series rule, but a user may be allowed to delete just this occurrence.
        permitted: choices.values.any?(&:present?),
        data: {
          controller: "calendars--eventlet-delete",
          action: "calendars--eventlet-delete#confirm",
          "calendars--eventlet-delete-occurrence-start-value": object.occurrence_start&.to_i,
          "calendars--eventlet-delete-prompts-value": delete_prompts(choices).to_json
        })
    end

    def scoped_delete?
      series_event.recurring? || series_event.eventlets.size > 1
    end

    # The modal steps for the delete controller, built here so all text is localized and escaped
    # server-side. `calendar` is nil when the event is on one calendar (scope is then "all");
    # `series` is nil when the event doesn't recur (scope is then "series"), otherwise it holds one
    # step per calendar scope. Calendar choices with no permitted series option are left out.
    def delete_prompts(choices)
      multi_calendar = series_event.eventlets.size > 1
      recurring = series_event.recurring?
      calendar_scopes = multi_calendar ? choices.keys.select { |scope| choices[scope].any? } : ["all"]
      {
        calendar: (calendar_delete_prompt(calendar_scopes, final: !recurring) if multi_calendar),
        series: (calendar_scopes.index_with { |s| series_delete_prompt(s, choices[s]) } if recurring)
      }
    end

    def calendar_delete_prompt(calendar_scopes, final:)
      others = series_event.eventlets.reject { |e| e.calendar_id == calendar.id }.map(&:calendar_name).sort
      items = [h.content_tag(:li, h.safe_join([h.content_tag(:strong, calendar.name), " (selected)"]))] +
        others.map { |name| h.content_tag(:li, name) }
      {
        title: t("calendars.eventlet_deletion.prompts.calendar.title"),
        content: h.safe_join([
          h.content_tag(:p, t("calendars.eventlet_deletion.prompts.calendar.content", name: name)),
          h.content_tag(:ul, h.safe_join(items))
        ]),
        choices: calendar_scopes.map do |scope|
          {label: t("calendars.eventlet_deletion.prompts.calendar.#{scope}", calendar: calendar.name),
           value: scope, variant: final ? "danger" : "default"}
        end
      }
    end

    def series_delete_prompt(calendar_scope, series_scopes)
      {
        title: t("calendars.eventlet_deletion.prompts.series.title"),
        content: h.content_tag(:p, t("calendars.eventlet_deletion.prompts.series.content_#{calendar_scope}",
          name: name, calendar: calendar.name)),
        choices: series_scopes.map do |scope|
          {label: t("calendars.eventlet_deletion.prompts.series.#{scope}"), value: scope, variant: "danger"}
        end
      }
    end

    def url_params
      h.params.permit(:origin_page)
    end

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
